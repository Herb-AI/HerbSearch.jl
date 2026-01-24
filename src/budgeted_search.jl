using CSV
using DataFrames
using HerbGrammar: rulenode2expr

"""
    BudgetedSearchController

A meta-controller that runs multiple synthesis attempts under a fixed budget
and adapts the grammar/problem between attempts.
"""
@kwdef mutable struct BudgetedSearchController
  problem::Problem

  iterator::ProgramIterator

  synth_fn::Function

  stop_checker::Function = (timed_solution) -> Bool

  attempts::Int
  selector::Function = results -> results
  updater::Function = (selected, iter) -> iter

  max_enumerations::Int

  interpret::Union{Function,Nothing}
  tags::Any

  last_state

  csv_file_name::String
  data_frame::DataFrame

  init_bank::Function = (problem, iter) -> bank
  mod::Module

  total_timeout::Float64 = 0.0
end

"""
    run_budget_search(ctrl)

Runs multiple synthesis attempts according to the configuration in
`BudgetedSearchController`.

For each attempt:
 1. Calls `ctrl.synth_fn(ctrl.problem, ctrl.iterator)`
 2. Records the returned value (which may be a single program or many)
 3. Tracks timing for performance analysis
 4. Uses `selector(results)` to choose promising candidates
 5. Uses `updater(selected, iterator, grammar)` to modify search for next round

Returns:
  - results :: Vector[Any]   (whatever synth_fn returns each attempt)
  - times   :: Vector{Float} (duration of each attempt)
  - total_time :: Float      (sum of all attempt durations)
"""
function run_budget_search(ctrl::BudgetedSearchController)
  results = []
  grammars = []
  times = []
  ctrl.data_frame = DataFrame(
    attempt = Int[],
    best_program = String[],
    program_score = Float64[],
    time = Float64[],
    new_updated_rules = String[]
  )
  bank = ctrl.init_bank(ctrl.problem, ctrl.iterator)

  time_count = 0
  budgeted_search_timed_out = false
  function run_search_loop!()
    for att in 1:ctrl.attempts
      solution = @timed ctrl.synth_fn(ctrl.problem, ctrl.iterator, ctrl.interpret, ctrl.max_enumerations, ctrl.tags, ctrl.mod, ctrl.last_state)
      ctrl.last_state = solution.value[2]
      push!(times, solution.time)
      push!(results, solution.value[1])
      selector_updater_start_time = time()
      selected = ctrl.selector(solution.value[1], bank)
      ctrl.iterator = ctrl.updater(selected, ctrl.iterator, bank, ctrl.last_state, ctrl.data_frame)
      time_for_attempt = solution.time + time() - selector_updater_start_time
      time_count += time_for_attempt
      ctrl.data_frame[nrow(ctrl.data_frame), :time] = time_for_attempt
      push!(grammars, get_grammar(ctrl.iterator))
      ctrl.stop_checker(solution) && break
    end
  end   
  if ctrl.total_timeout > 0
    bs_task = Threads.@spawn run_search_loop!()
    start_time = time()
    while !istaskdone(bs_task) && (time() - start_time) < ctrl.total_timeout
      sleep(1.0)
    end
    if !istaskdone(bs_task)
      println("WARNING: Total search timeout reached after $(ctrl.total_timeout) seconds")
      println("Task will continue in background, proceeding to save results...")
      budgeted_search_timed_out = true
    end
  else
    run_search_loop!()
  end
  
  # this part is just for logging the final result
  final_grammar = get_grammar(ctrl.iterator)
  if !isempty(results) && !isnothing(last(results))
    best_prog = nothing
    best_score = 0.0
    for solution in results
      if(solution[4] > best_score)
        best_prog = solution[1]
        best_score = solution[4]
      end
    end
    push!(ctrl.data_frame, (
      attempt = ctrl.attempts + 1,  # Mark as final
      best_program = isnothing(best_prog) ? "Nothing" : string(rulenode2expr(best_prog, final_grammar)),
      program_score = best_score,
      time = time_count,
      new_updated_rules = "Final result so no updates"
    ))
  end

  push!(ctrl.data_frame, (
    attempt = -1,
    best_program = "Final grammar",
    program_score = -1.0,
    time = 0,
    new_updated_rules = string(final_grammar)
  ))

  push!(ctrl.data_frame, (
    attempt = -2,
    best_program = "Timed out: $(budgeted_search_timed_out)",
    program_score = -1.0,
    time = 0,
    new_updated_rules = " "
  ))
  # Write DataFrame to CSV (column names are automatically used as headers)
  CSV.write(ctrl.csv_file_name, ctrl.data_frame)
  return results, times, time_count, grammars

end
