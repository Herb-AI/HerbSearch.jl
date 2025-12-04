using HerbGrammar, HerbCore, HerbSpecification

using HerbSearch: BFSIterator, get_grammar
using HerbSearch.BudgetedSearch
using HerbSearch.UsefulSubprograms
using Test

g = HerbGrammar.@csgrammar begin
  Number = 0 | 2 | 4 | 6 | 8
  Number = x
  Number = Number + Number
  Number = Number - Number
  Number = Number * Number
end

@testset verbose = true "Budgeted search with useful subprograms tests" begin
  # Create input-output examples
  examples = [HerbSpecification.IOExample(Dict(:x => x), 4x + 6) for x ∈ 1:5]
  problem_1 = HerbSpecification.Problem("example", examples)
  iterator_1 = BFSIterator(g, :Number)

  ctrl = BudgetedSearchController(
    problem=problem_1,
    grammar=g,
    iterator=iterator_1,
    synth_fn=UsefulSubprograms.synth_fn,
    attempts=3,
    selector=UsefulSubprograms.selector,
    updater=UsefulSubprograms.updater
  )

  @test ctrl.problem == problem_1
  @test ctrl.iterator == iterator_1

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


