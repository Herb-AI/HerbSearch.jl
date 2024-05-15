Base.@doc """
    @programiterator FixedShapedIterator()

Enumerates all programs that extend from the provided fixed shaped tree.
The [Solver](@ref) is required to be in a state without any [Hole](@ref)s.

!!! warning: this iterator is used as a baseline for the constraint propagation thesis. After the thesis, this iterator can (and should) be deleted.
""" FixedShapedIterator
@programiterator FixedShapedIterator()

"""
    priority_function(::FixedShapedIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Assigns a priority value to a `tree` that needs to be considered later in the search. Trees with the lowest priority value are considered first.
"""
function priority_function(
    ::FixedShapedIterator, 
    g::AbstractGrammar, 
    tree::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}}
)
    parent_value + 1;
end


"""
    hole_heuristic(::FixedShapedIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}

Defines a heuristic over fixed shaped holes. Returns a [`HoleReference`](@ref) once a hole is found.
"""
function hole_heuristic(::FixedShapedIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}
    return heuristic_leftmost_fixed_shaped_hole(node, max_depth);
end

"""
    Base.iterate(iter::FixedShapedIterator)

Describes the iteration for a given [`TopDownIterator`](@ref) over the grammar. The iteration constructs a [`PriorityQueue`](@ref) first and then prunes it propagating the active constraints. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::FixedShapedIterator)
    # Priority queue with number of nodes in the program
    pq :: PriorityQueue{SolverState, Union{Real, Tuple{Vararg{Real}}}} = PriorityQueue()

    solver = iter.solver
    @assert !contains_nonuniform_hole(get_tree(iter.solver)) "A FixedShapedIterator cannot iterate partial programs with Holes"

    if isfeasible(solver)
        enqueue!(pq, get_state(solver), priority_function(iter, get_grammar(solver), get_tree(solver), 0))
    end
    return _find_next_complete_tree(solver, pq, iter)
end


"""
    Base.iterate(iter::FixedShapedIterator, pq::DataStructures.PriorityQueue)

Describes the iteration for a given [`TopDownIterator`](@ref) and a [`PriorityQueue`](@ref) over the grammar without enqueueing new items to the priority queue. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::FixedShapedIterator, pq::DataStructures.PriorityQueue)
    return _find_next_complete_tree(iter.solver, pq, iter)
end

"""
    _find_next_complete_tree(solver::Solver, pq::PriorityQueue, iter::FixedShapedIterator)::Union{Tuple{RuleNode, PriorityQueue}, Nothing}

Takes a priority queue and returns the smallest AST from the grammar it can obtain from the queue or by (repeatedly) expanding trees that are in the queue.
Returns `nothing` if there are no trees left within the depth limit.
"""
function _find_next_complete_tree(
    solver::Solver, 
    pq::PriorityQueue,
    iter::FixedShapedIterator
)::Union{Tuple{RuleNode, PriorityQueue}, Nothing}
    while length(pq) ≠ 0
        (state, priority_value) = dequeue_pair!(pq)
        load_state!(solver, state)

        hole_res = hole_heuristic(iter, get_tree(solver), typemax(Int))
        if hole_res ≡ already_complete
            #the tree is complete
            return (get_tree(solver), pq)
        elseif hole_res ≡ limit_reached
            # The maximum depth is reached
            continue
        elseif hole_res isa HoleReference
            # UniformHole was found
            (; hole, path) = hole_res
    
            rules = findall(hole.domain)
            number_of_rules = length(rules)
            for (i, rule_index) ∈ enumerate(findall(hole.domain))
                if i < number_of_rules
                    state = save_state!(solver)
                end
                @assert isfeasible(solver) "Attempting to expand an infeasible tree: $(get_tree(solver))"
                remove_all_but!(solver, path, rule_index)
                if isfeasible(solver)
                    enqueue!(pq, get_state(solver), priority_function(iter, get_grammar(solver), get_tree(solver), priority_value))
                end
                if i < number_of_rules
                    load_state!(solver, state)
                end
            end
        end
    end
    return nothing
end
