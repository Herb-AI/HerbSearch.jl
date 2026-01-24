
using HerbGrammar, HerbCore, HerbSpecification

using HerbSearch: BudgetedSearchController, BFSIterator, get_grammar, run_budget_search, synth, freeze_state
using HerbSearch.UsefulSubprograms
using MLStyle
using DataFrames
using CSV

using HerbBenchmarks.PBE_SLIA_Track_2019: interpret_sygus
using HerbBenchmarks# PBE_SLIA_Track_2019, get_all_problem_grammar_pairs, make_interpreter, get_relevant_tags
using MPI
MPI.Init()
comm = MPI.COMM_WORLD
mpi_rank = MPI.Comm_rank(comm)
mpi_size = MPI.Comm_size(comm)

arg_max_depth = parse(Int64, ARGS[1])
arg_max_size = parse(Int64, ARGS[2])
arg_max_enumerations = parse(Int64, ARGS[3])
arg_num_attempts = parse(Int64, ARGS[4])

# Configurable output directory (5th argument, defaults to "results")
output_dir = length(ARGS) >= 5 ? ARGS[5] : "results"
mkpath(output_dir)  # Create directory if it doesn't exist

arg_total_timeout = parse(Float64, ARGS[6])

problem_grammar_pairs = get_all_problem_grammar_pairs(PBE_SLIA_Track_2019)[2:end]
start_problem = div(length(problem_grammar_pairs)*(mpi_rank), mpi_size) + 1
end_problem = div(length(problem_grammar_pairs)*(mpi_rank + 1), mpi_size)

println("Rank $mpi_rank from $start_problem to $end_problem ($(end_problem - start_problem + 1) total)")

for pair in problem_grammar_pairs[start_problem:end_problem]
  problem = pair.problem
  grammar = deepcopy(pair.grammar)

  iterator = BFSIterator(
    grammar,
    :Start,
    max_depth=arg_max_depth,
    max_size=arg_max_size
  )

  tags = get_relevant_tags(grammar)
  eval(make_interpreter(grammar))

  ctrl_bu = BudgetedSearchController(
    problem=problem,
    iterator=iterator,
    synth_fn=UsefulSubprograms.synth_fn,
    attempts=arg_num_attempts,
    selector=UsefulSubprograms.selector,
    updater=UsefulSubprograms.updater,
    max_enumerations=arg_max_enumerations,
    interpret=interpret_sygus,
    tags=tags,
    stop_checker=UsefulSubprograms.stop_checker,
    init_bank=UsefulSubprograms.init_bank,
    last_state=nothing,
    csv_file_name="$(output_dir)/$(problem.name)_budgeted_bfs.csv",
    data_frame=DataFrame(),
    mod=PBE_SLIA_Track_2019,
    total_timeout=arg_total_timeout
  )

  println("Rank $mpi_rank: Starting benchmark $(problem.name)")

  results_bu, times_bu, total_bu, grammars = run_budget_search(ctrl_bu)

  println("Rank $mpi_rank finished $(problem.name) Time: $(total_bu)")

  if !isempty(results_bu) && !isnothing(last(results_bu)) && !isnothing(last(results_bu)[1])
    program = rulenode2expr(last(results_bu)[1], get_grammar(iterator.solver))
    println("Found solution: $program")

    # Append to log file instead of overwriting
    open("$(output_dir)/program_solutions_log_bfs_rank_$(mpi_rank).txt", "a") do io
      println(io, "Problem: $(problem.name)")
      println(io, "BFS Results = ", results_bu)
      println(io, "BFS Times = ", times_bu)
      println(io, "BFS Total = ", total_bu)
      println(io, "Intermediate Grammars = ", grammars)
      println(io, "BFS Final Grammar = ", get_grammar(iterator.solver))
      if !isempty(results_bu)
        println(io, "BFS Final Program = ", rulenode2expr(last(results_bu)[1], get_grammar(iterator.solver)))
      end
      println(io, "Control: ")
    end
  else
    println("No solution found for $(problem.name)")
  end

  # baseline (control) - same enumeration budget but no grammar updates
  println("Rank $mpi_rank: Starting CONTROL for $(problem.name)")

  grammar_control = deepcopy(pair.grammar)

  iterator_control = BFSIterator(
    grammar_control,
    :Start,
    max_depth=arg_max_depth,
    max_size=arg_max_size
  )

  tags_control = get_relevant_tags(grammar_control)

  # DataFrame to track control results (same structure as budgeted for easy comparison)
  control_df = DataFrame(
    attempt = Int[],
    best_program = String[],
    program_score = Float64[],
    iterations = Int[],
    time_seconds = Float64[]
  )

  overall_best_score = -1.0
  overall_best_program = nothing
  last_state_control = nothing
  total_control_time = 0.0
  timed_out = false
  function run_control_loop!()
  for attempt in 1:arg_num_attempts
    start_time = time()
    grammar_ctrl = get_grammar(iterator_control.solver)

    attempt_best_score = -1.0
    attempt_best_program = nothing
    num_iterations = 0

    iteration = nothing
    if !isnothing(last_state_control)
      iteration = iterate(iterator_control, last_state_control)
    else
      iteration = iterate(iterator_control)
    end

    while !isnothing(iteration)
      (candidate_program, state) = iteration
      last_state_control = state

      passed_examples = UsefulSubprograms.evaluate_with_interpreter(
        problem, candidate_program, interpret_sygus, tags_control,
        shortcircuit=false, allow_evaluation_errors=true
      )
      num_iterations += 1

      score = count(passed_examples) / length(passed_examples)

      if score == 1
        candidate_program = freeze_state(candidate_program)
        attempt_best_score = score
        attempt_best_program = candidate_program
        println("Rank $mpi_rank: CONTROL found optimal at iteration $num_iterations")
        break
      elseif score > attempt_best_score
        attempt_best_score = score
        attempt_best_program = freeze_state(candidate_program)
      end

      if num_iterations >= arg_max_enumerations
        break
      end

      iteration = iterate(iterator_control, state)
    end

    attempt_time = time() - start_time
    total_control_time += attempt_time

    # Update overall best
    if attempt_best_score > overall_best_score
      overall_best_score = attempt_best_score
      overall_best_program = attempt_best_program
    end

    # Record this attempt
    push!(control_df, (
      attempt = attempt,
      best_program = isnothing(attempt_best_program) ? "Nothing" : string(rulenode2expr(attempt_best_program, grammar_ctrl)),
      program_score = attempt_best_score,
      iterations = num_iterations,
      time_seconds = attempt_time
    ))

    # Early exit if optimal found
    if isnothing(iteration) || attempt_best_score == 1.0
      break
    end
  end
  end

  if arg_total_timeout > 0
    control_task = Threads.@spawn run_control_loop!()
    # Poll for completion instead of using timedwait (avoids scheduler conflicts)
    start_time = time()
    while !istaskdone(control_task) && (time() - start_time) < arg_total_timeout
      sleep(1.0)
    end
    if !istaskdone(control_task)
      println("WARNING: CONTROL timeout reached after $(arg_total_timeout) seconds")
      println("Task will continue in background, proceeding to save results...")
      timed_out = true
    end
  else
    run_control_loop!()
  end

  # Add final summary row
  push!(control_df, (
    attempt = -1,  # Mark as summary row
    best_program = isnothing(overall_best_program) ? "Nothing" : string(rulenode2expr(overall_best_program, get_grammar(iterator_control.solver))),
    program_score = overall_best_score,
    iterations = -1,
    time_seconds = total_control_time
  ))

  # Save control CSV
  CSV.write("$(output_dir)/$(problem.name)_control_bfs.csv", control_df)

  println("Rank $mpi_rank: CONTROL finished $(problem.name) - Best score: $overall_best_score, Time: $total_control_time")

end  # end of outer for pair loop


println("Rank $mpi_rank: Finished all benchmarks, waiting at barrier")
flush(stdout)
# MPI.Barrier(comm)
println("Rank $mpi_rank: Passed barrier, finalizing")
flush(stdout)
MPI.Finalize()
