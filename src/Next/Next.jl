module Next
using DrWatson: @stable

@stable begin

include("heuristics.jl")

struct BFSIterator{D<:DerivationHeuristicStyle,H<:HoleHeuristicStyle,C<:ConstraintStyle,G<:AbstractGrammar,S<:AbstractRuleNode} <: TopDownIterator
    grammar::G
    start::S
end

derivation_style(iter::BFSIterator{D}) where {D} = D
hole_heuristic_style(iter::BFSIterator{D,H}) where {D,H} = H

function derivation_heuristic(iter, grammar::AbstractGrammar, indices)
    return derivation_heuristic(derivation_style(iter), grammar, indices)
end
function hole_heuristic(hhr::HoleHeuristic, max_depth)
    return hole_heuristic(hole_heuristic_style(hhr), get_rulenode(hhr), max_depth)
end

struct TopDownState{P,S}
    queue::P
    solver::S
end
get_queue(tds::TopDownState) = tds.queue
get_solver(tds::TopDownState) = tds.solver

function Base.iterate(iter::TopDownIterator)
    queue = _init_queue(iter)
    solver = GenericSolver(iter)
    state_priority_pairs = iterate(solver)
    if !isnothing(next)
        push!(queue, state_priority_pairs...)
        state = TopDownState(queue, solver)

        return Base.iterate(iter, state)
    else
        return nothing
    end
end

function Base.iterate(iter::TopDownIterator, state::TopDownState)
    while !isempty(get_queue(state))
        (queued_state, priority_value) = popfirst!(get_queue(state))
        solver = get_solver(state)
        next = iterate(solver, queued_state)

        if !isnothing(next)
            solution, queued_state = next
            
            return solution
        end # is isnothing(solution) then 
    end
    return nothing
end

end # @stable
end # module Next
