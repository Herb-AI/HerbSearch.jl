using HerbGrammar, HerbCore, HerbSpecification

using HerbSearch: BudgetedSearchController, BFSIterator, get_grammar, run_budget_search
using HerbSearch.UsefulSubprograms
using Test

using HerbBenchmarks.String_transformations_2020


@testset verbose = true "Budgeted search with useful subprograms tests" begin
  # The id has to be matching
  grammar = String_transformations_2020.grammar_string
  problem = String_transformations_2020.problem_100
  iterator_1 = BFSIterator(grammar, :Start; max_depth=6)
  ctrl = BudgetedSearchController(
    problem=problem,
    iterator=iterator_1,
    synth_fn=UsefulSubprograms.synth_fn,
    attempts=10,
    selector=UsefulSubprograms.selector,
    updater=UsefulSubprograms.updater,
    stop_checker=UsefulSubprograms.stop_checker,
    init_bank=UsefulSubprograms.init_bank
  )

  results, times, total = run_budget_search(ctrl)
  println("Results = ", results)
  println("Times = ", times)
  println("Total = ", total)
end
