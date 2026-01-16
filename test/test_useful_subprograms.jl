using HerbGrammar, HerbCore, HerbSpecification

using HerbSearch: BudgetedSearchController, BFSIterator, get_grammar, run_budget_search, get_max_size, CostBasedBottomUpIterator, get_costs
using HerbSearch.UsefulSubprograms
using Test

g = HerbGrammar.@csgrammar begin
  Number = 0 | 2 | 4 | 6 | 8
  Number = x
  Number = Number + Number
  Number = Number - Number
  Number = Number * Number
end

examples = [HerbSpecification.IOExample(Dict(:x => x), 4x + 6) for x ∈ 1:5]
problem_1 = HerbSpecification.Problem("example", examples)


@testset verbose = true "Budgeted search with useful subprograms and bottom-up iterator" begin
  grammar = deepcopy(g)
  grammar_bu = isprobabilistic(grammar) ? grammar : init_probabilities!(deepcopy(grammar))
  costs = get_costs(grammar_bu)
  iterator_2 = CostBasedBottomUpIterator(
    grammar_bu,
    :Number;
    max_depth=10,
    max_cost=20.0,
    current_costs=costs
  )

  # ctrl_bu = BudgetedSearchController(
  #   problem=problem,
  #   iterator=iterator_2,
  #   synth_fn=UsefulSubprograms.synth_fn,
  #   attempts=arg_num_attempts,
  #   selector=UsefulSubprograms.selector,
  #   updater=UsefulSubprograms.updater,
  #   max_enumerations=arg_max_enumerations,
  #   interpret=interpret,
  #   tags=tags,
  #   stop_checker=UsefulSubprograms.stop_checker,
  #   init_bank=UsefulSubprograms.init_bank,
  #   mod=PBE_SLIA_Track_2019
  # )
  ctrl_bu = BudgetedSearchController(
    problem=problem_1,
    iterator=iterator_2,
    synth_fn=UsefulSubprograms.synth_fn,
    attempts=10,
    selector=UsefulSubprograms.selector,
    updater=UsefulSubprograms.updater,
    max_enumerations=100,
    interpret=nothing,
    tags=nothing,
    stop_checker=UsefulSubprograms.stop_checker,
    init_bank=UsefulSubprograms.init_bank,
    mod=Main
  )

  results_bu, times_bu, total_bu = run_budget_search(ctrl_bu)
  if !isnothing(last(results_bu)[1])
    program = rulenode2expr(last(results_bu)[1], get_grammar(iterator_2.solver))
    println("Found solution: $program")
  else
    println("No solution found")
  end
end

@testset verbose = true "Budgeted search with useful subprograms tests" begin
  # Create input-output examples
  iterator_1 = BFSIterator(g, :Number; max_depth=10)

  ctrl = BudgetedSearchController(
    problem=problem_1,
    iterator=iterator_1,
    synth_fn=UsefulSubprograms.synth_fn,
    attempts=10,
    selector=UsefulSubprograms.selector,
    updater=UsefulSubprograms.updater,
    stop_checker=UsefulSubprograms.stop_checker,
    init_bank=UsefulSubprograms.init_bank,
    mod=Main,
  )

  @test ctrl.problem == problem_1
  @test ctrl.iterator == iterator_1

  println(get_max_size(iterator_1))
  println("Running budgeted search...")
  println("Problem: 4x + 6, for x in 1:5")

  results, times, total = run_budget_search(ctrl)

  println("\n=== Results ===")
  println("Number of results: ", length(results))
  println("Times: ", times)
  println("Total time: ", total)
  println("\nResults details:")
  for (i, result) in enumerate(results)
    println("  Result $i: ", result)
  end
  println("Final grammar: ", get_grammar(ctrl.iterator.solver))

end


