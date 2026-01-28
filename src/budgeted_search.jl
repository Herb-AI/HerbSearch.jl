using ..HerbSearch: ProgramIterator, GenericBUState
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

    iterator::ProgramIterator
    state::Union{GenericBUState, Nothing} = nothing

    synth_fn::Function

    stop_checker::Function = (timed_solution) -> Bool
    update_solution::Function = (timed_solution, best_solution, best_score) -> (AbstractRuleNode, Float64)
    extract_state::Function
    
    attempts::Int
    selector::Function
    updater::Function = (selected, iter) -> (iter)
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
    times = []

    time_count = 0

    best_solution= nothing
    best_score = nothing
    best_program_enumeration_step = nothing

    for att in 1:ctrl.attempts

        println("BUDGETED ATTEMPT $(att)")

        solution = @timed ctrl.synth_fn(ctrl.problem, ctrl.iterator; iterator_state=ctrl.state)
        time_count += solution.time

    
        push!(times, solution.time)
        # push!(results, solution.value)

        best_solution, best_score, best_program_enumeration_step = ctrl.update_solution(solution, best_solution, best_score, best_program_enumeration_step)

        ctrl.stop_checker(solution) && break

        selected = ctrl.selector(solution.value, ctrl.iterator, ctrl.problem)
        # ctrl.iterator = ctrl.updater(selected, ctrl.iterator)
        ctrl.iterator, ctrl.state = ctrl.extract_state(solution.value, selected, ctrl.iterator)
    end

    return best_solution, best_score, best_program_enumeration_step, times, time_count

end