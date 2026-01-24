using HerbGrammar, HerbCore, HerbSpecification

using HerbSearch: BudgetedSearchController, BFSIterator, CostBasedBottomUpIterator, get_grammar, run_budget_search, get_costs, synth, freeze_state
using HerbSearch.UsefulSubprograms
using Test
using MLStyle
using DataFrames
using CSV

import HerbBenchmarks
using HerbBenchmarks.PBE_SLIA_Track_2019: interpret_sygus
using HerbBenchmarks: PBE_SLIA_Track_2019, get_all_problem_grammar_pairs, make_interpreter, get_relevant_tags

# Arg 1 - max_depth
# Arg 2 - max_cost
# Arg 3 - num_attempts

arg_max_depth = parse(Int64, ARGS[1])
arg_max_size = parse(Int64, ARGS[2])
arg_max_enumerations = parse(Int64, ARGS[3])
arg_max_cost = parse(Float64, ARGS[4])
arg_num_attempts = parse(Int64, ARGS[5])

# Configurable output directory (6th argument, defaults to "results")
output_dir = length(ARGS) >= 6 ? ARGS[6] : "results"
mkpath(output_dir)  # Create directory if it doesn't exist


# @testset "Sanity Check" begin
#
#   for pair in get_all_problem_grammar_pairs(PBE_SLIA_Track_2019)[2:5]
#     problem = pair.problem
#     grammar = deepcopy(pair.grammar)
#     grammar_bu = isprobabilistic(grammar) ? grammar : init_probabilities!(deepcopy(grammar))
#     costs = get_costs(grammar_bu)
#
#     iterator_2 = CostBasedBottomUpIterator(
#       grammar_bu,
#       :Start;
#       max_depth=arg_max_depth,
#       max_cost=arg_max_cost,
#       current_costs=costs
#     )
#     println("Starting synth")
#     result = synth(problem, iterator_2, mod=PBE_SLIA_Track_2019, allow_evaluation_errors=true)
#
#     println("Synth done! Result: ", result)
#
#     # tags = get_relevant_tags(grammar_bu)
#     # eval(make_interpreter(grammar_bu))
#   end
# end

# @testset "BFSIterator solution" begin
# for pair in get_all_problem_grammar_pairs(PBE_SLIA_Track_2019)[2:5]
#   g = pair.grammar
#   problem = pair.problem
#
#   println("\n=== Solving problem: $(problem.name) ===")
#
#   iterator = BFSIterator(g, :Start, max_depth=15)
#
#   # Use allow_evaluation_errors=true to handle 0-based indexing issues in SyGuS benchmarks
#   solution, flag = synth(problem, iterator, mod=PBE_SLIA_Track_2019, allow_evaluation_errors=true)
#
#   if !isnothing(solution)
#     program = rulenode2expr(solution, g)
#     println("Found solution (flag=$flag): $program")
#
#     # Append to log file instead of overwriting
#     open("program_solutions_log.txt", "a") do io
#       println(io, "Problem: $(problem.name)")
#       println(io, "Flag: $flag")
#       println(io, "Solution: $program")
#       println(io, "---")
#     end
#   else
#     println("No solution found for $(problem.name)")
#   end
#
# end
# end
# function create_patched_interpret(orig_interpret)                                                                                                
#       function patched(prog::AbstractRuleNode, grammar_tags::Dict{Int, Any}, input::Dict{Symbol, Any})                                             
#           r = get_rule(prog)                                                                                                                       
#           c = get_children(prog)                                                                                                                   
#           tag = grammar_tags[r]                                                                                                                    
#
#           # Handle non-terminal pass-through                                                                                                       
#           if tag in [:ntString, :ntInt, :ntBool]                                                                                                   
#               return patched(c[1], grammar_tags, input)                                                                                            
#           end                                                                                                                                      
#           # Handle integer literals                                                                                                                
#           if tag isa Integer                                                                                                                       
#               return tag            
#           end                       
#           # Handle string literals  
#           if tag isa String         
#               return tag            
#           end                       
#           # Handle boolean literals 
#           if tag == :true           
#               return true           
#           elseif tag == :false      
#               return false          
#           end                       
#
#           return Base.invokelatest(orig_interpret, prog, grammar_tags, input)                                                                      
#       end                           
#       return patched                
#   end 

@testset "Cost-based bottom-up iterator" begin

  for pair in get_all_problem_grammar_pairs(PBE_SLIA_Track_2019)[5:5]

    # ==================== CONTROL RUN (no grammar updates) ====================
    problem = PBE_SLIA_Track_2019.problem_split_numbers_from_units_of_measure_1
    println("\n=== Starting CONTROL run for $(problem.name) ===")

    grammar = deepcopy(HerbBenchmarks.PBE_SLIA_Track_2019.grammar_split_numbers_from_units_of_measure_1)

    grammar_control = deepcopy(HerbBenchmarks.PBE_SLIA_Track_2019.grammar_split_numbers_from_units_of_measure_1)
    p_grammar_control = isprobabilistic(grammar_control) ? grammar_control : init_probabilities!(deepcopy(grammar_control))
    costs_control = get_costs(p_grammar_control)

    iterator_control = CostBasedBottomUpIterator(
      p_grammar_control,
      :Start;
      max_cost=arg_max_cost,
      max_size=arg_max_size,
      current_costs=costs_control
    )

    tags_control = get_relevant_tags(p_grammar_control)

    overall_best_score = -1.0
    overall_best_program = nothing
    last_state_control = nothing
    total_iterations = 0

    for attempt in 1:arg_num_attempts
      num_iterations = 0

      iteration = nothing
      if !isnothing(last_state_control)
        iteration = iterate(iterator_control, last_state_control)
      else
        iteration = iterate(iterator_control)
      end

      while !isnothing(iteration)
        println("synth_fn: iter $num_iterations - start")
        flush(stdout)
        (candidate_program, state) = iteration
        last_state_control = state

        passed_examples = UsefulSubprograms.evaluate_with_interpreter(
          problem, candidate_program, interpret_sygus, tags_control,
          shortcircuit=false, allow_evaluation_errors=true
        )
        num_iterations += 1
        total_iterations += 1

        score = count(passed_examples) / length(passed_examples)

        if score > overall_best_score
          overall_best_score = score
          overall_best_program = freeze_state(candidate_program)
        end

        if score == 1 || num_iterations >= arg_max_enumerations
          break
        end

        iteration = iterate(iterator_control, state)
      end

      println("CONTROL attempt $attempt: best_score=$overall_best_score, iterations=$num_iterations")

      if isnothing(iteration) || overall_best_score == 1.0
        break
      end
    end

    println("CONTROL finished: Best score=$overall_best_score, Total iterations=$total_iterations")
    if !isnothing(overall_best_program)
      println("CONTROL best program: ", rulenode2expr(overall_best_program, get_grammar(iterator_control.solver)))
    end
    println("=" ^ 60)
    grammar = deepcopy(HerbBenchmarks.PBE_SLIA_Track_2019.grammar_split_numbers_from_units_of_measure_1)

    problem = PBE_SLIA_Track_2019.problem_split_numbers_from_units_of_measure_1
    # problem = pair.problem
    # grammar = deepcopy(pair.grammar)
    grammar_bu = isprobabilistic(grammar) ? grammar : init_probabilities!(deepcopy(grammar))
    costs = get_costs(grammar_bu)

    iterator_2 = CostBasedBottomUpIterator(
      grammar_bu,
      :Start;
      # max_depth=arg_max_depth,
      max_cost=arg_max_cost,
      max_size=arg_max_size,
      current_costs=costs
    )
                                                                                                                                                   
  # eval(make_interpreter(grammar_test))                                                                                                                  
  # println("methods test: ", methods(interpret))
  #
  tags = get_relevant_tags(grammar)
  # #   println(methods(make_interpreter))
  # expr = make_interpreter(grammar)                                                                                                                 
  # println("expr repr: ", repr(expr))
  #   eval(make_interpreter(grammar))   
  # patched_interpret = create_patched_interpret(interpret)
                                                                                                                                                   
      # println("interpret methods: ", methods(interpret))
    # println(pathof(HerbBenchmarks))

    # Print the grammar rules and their tags                                                                                                         
  # println("Grammar rules:")                                                                                                                        
  # for (i, rule) in enumerate(grammar.rules)                                                                                                        
  #     println("Rule $i: $rule => tag: $(get(tags, i, :missing))")                                                                                  
  # end
    # patched_interpret = create_patched_interpret(interpret_sygus) 

    ctrl_bu = BudgetedSearchController(
      problem=problem,
      iterator=iterator_2,
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
      csv_file_name="$(output_dir)/$(problem.name)_log.csv",
      data_frame=DataFrame(),
      mod=PBE_SLIA_Track_2019
    )

    results_bu, times_bu, total_bu, grammars = run_budget_search(ctrl_bu)
    if !isnothing(last(results_bu)[1])
      program = rulenode2expr(last(results_bu)[1], get_grammar(iterator_2.solver))
      println("Found solution: $program")

      # Append to log file instead of overwriting
      open("$(output_dir)/program_solutions_log.txt", "a") do io
        println(io, "Problem: $(problem.name)")
        println(io, "Bottom-up Results = ", results_bu)
        println(io, "Bottom-up Times = ", times_bu)
        println(io, "Bottom-up Total = ", total_bu)
        println(io, "Intermediate Grammars = ", grammars)
        println(io, "Bottom-up Final Grammar = ", get_grammar(iterator_2.solver))
        if !isempty(results_bu)
          println(io, "Bottom-up Final Program = ", rulenode2expr(last(results_bu)[1], get_grammar(iterator_2.solver)))
        end
        println(io, "---")
      end
    else
      println("No solution found for $(problem.name)")
    end

  end

  # @testset verbose = true "Budgeted search with useful subprograms tests" begin
  #   # The id has to be matching
  #   for pair in get_all_problem_grammar_pairs(PBE_SLIA_Track_2019)[2:5]
  #     problem = pair.problem
  #     grammar = deepcopy(pair.grammar)
  #     iterator_1 = BFSIterator(grammar, :Start; max_depth=6)
  #     ctrl = BudgetedSearchController(
  #       problem=problem,
  #       iterator=iterator_1,
  #       synth_fn=UsefulSubprograms.synth_fn,
  #       attempts=10,
  #       selector=UsefulSubprograms.selector,
  #       updater=UsefulSubprograms.updater,
  #       stop_checker=UsefulSubprograms.stop_checker,
  #       init_bank=UsefulSubprograms.init_bank
  #     )
  #
  #     results, times, total = run_budget_search(ctrl)
  #     println("Results = ", results)
  #     println("Times = ", times)
  #     println("Total = ", total)
  #     println("Final Grammar = ", get_grammar(iterator_1.solver))
  #     println("Final Program = ", rulenode2expr(last(results)[1], get_grammar(iterator_1.solver)))
  #   end
  # end
end
