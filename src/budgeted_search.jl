module BudgetedSearch

export BudgetedSearchController, run_budget_search

using ..HerbSearch: ProgramIterator
using ..HerbGrammar
using ..HerbCore
using ..HerbSpecification: Problem 

"""
    BudgetedSearchController

A meta-controller that runs multiple synthesis attempts under a fixed budget
and adapts the grammar/problem between attempts.
"""
@kwdef mutable struct BudgetedSearchController
    problem:: Problem
    grammar::ContextSensitiveGrammar

    iterator::ProgramIterator

    synth_fn::Function
    
    attempts::Int
    selector::Function = results -> results
    updater::Function = (selected, iter, grammar) -> iter
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
function run_budget_search(ctrl::BudgetedSearchController, problem)
    results = []
    times = []

    time_count = 0

    for att in 1:ctrl.attempts
        solution = @timed ctrl.synth_fn(ctrl.problem, ctrl.iterator)
        time_count += solution.time
        push!(times, solution.time)
        push!(results, solution.value)

        selected = ctrl.selector(results)
        ctrl.iterator = ctrl.updater(selected, ctrl.iterator, ctrl.grammar)
    end

    return results, times, time_count


end

end