using HerbGrammar, HerbCore, HerbSpecification

using HerbSearch: BudgetedSearchController, BFSIterator, CostBasedBottomUpIterator, get_grammar, run_budget_search, get_costs, synth
using HerbSearch.UsefulSubprograms
using Test
using MLStyle

using HerbBenchmarks#: PBE_SLIA_Track_2019, get_all_problem_grammar_pairs, make_interpreter, get_relevant_tags

# Arg 1 - max_depth
# Arg 2 - max_cost
# Arg 3 - num_attempts

arg_max_depth = parse(Int64, ARGS[1])
arg_max_size = parse(Int64, ARGS[2])
arg_max_enumerations = parse(Int64, ARGS[3])
arg_max_cost = parse(Float64, ARGS[4])
arg_num_attempts = parse(Int64, ARGS[5])


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

@testset "Cost-based bottom-up iterator" begin

  for pair in get_all_problem_grammar_pairs(PBE_SLIA_Track_2019)[2:5]
    problem = pair.problem
    grammar = deepcopy(pair.grammar)
    grammar_bu = isprobabilistic(grammar) ? grammar : init_probabilities!(deepcopy(grammar))
    costs = get_costs(grammar_bu)

    iterator_2 = CostBasedBottomUpIterator(
      grammar_bu,
      :Start;
      max_depth=arg_max_depth,
      max_cost=arg_max_cost,
      max_size=arg_max_size,
      current_costs=costs
    )

    tags = get_relevant_tags(grammar)
    eval(make_interpreter(grammar))

    ctrl_bu = BudgetedSearchController(
      problem=problem,
      iterator=iterator_2,
      synth_fn=UsefulSubprograms.synth_fn,
      attempts=arg_num_attempts,
      selector=UsefulSubprograms.selector,
      updater=UsefulSubprograms.updater,
      max_enumerations=arg_max_enumerations,
      interpret=interpret,
      tags=tags,
      stop_checker=UsefulSubprograms.stop_checker,
      init_bank=UsefulSubprograms.init_bank,
      mod=PBE_SLIA_Track_2019
    )

    results_bu, times_bu, total_bu, grammars = run_budget_search(ctrl_bu)
    if !isnothing(last(results_bu)[1])
      program = rulenode2expr(last(results_bu)[1], get_grammar(iterator_2.solver))
      println("Found solution: $program")

      # Append to log file instead of overwriting
      open("program_solutions_log.txt", "a") do io
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
