Base.@doc """
    @programiterator FixedShapedIterator()

Enumerates all programs that extend from the provided fixed shaped tree.
The [Solver](@ref) is required to be in a state without any [VariableShapedHole](@ref)s 
""" FixedShapedIterator
@programiterator FixedShapedIterator()

"""
    priority_function(::FixedShapedIterator, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Assigns a priority value to a `tree` that needs to be considered later in the search. Trees with the lowest priority value are considered first.

- `g`: The grammar used for enumeration
- `tree`: The tree that is about to be stored in the priority queue
- `parent_value`: The priority value of the parent [`State`](@ref)
"""
function priority_function(
    ::FixedShapedIterator, 
    g::Grammar, 
    tree::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}}
)
    parent_value + 1;
end


"""
    hole_heuristic(::TopDownIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}

Defines a heuristic over fixed shaped holes. Returns a [`HoleReference`](@ref) once a hole is found.
"""
function hole_heuristic(::FixedShapedIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}
    return heuristic_leftmost_fixed_shaped_hole(node, max_depth);
end

"""
    Base.iterate(iter::TopDownIterator)

Describes the iteration for a given [`TopDownIterator`](@ref) over the grammar. The iteration constructs a [`PriorityQueue`](@ref) first and then prunes it propagating the active constraints. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::FixedShapedIterator)
    # Priority queue with number of nodes in the program
    pq :: PriorityQueue{State, Union{Real, Tuple{Vararg{Real}}}} = PriorityQueue()

    solver = iter.solver
    @assert !contains_variable_shaped_hole(get_tree(iter.solver)) "A FixedShapedIterator cannot iterate partial programs with VariableShapedHoles"

    enqueue!(pq, get_state(solver), priority_function(iter, get_grammar(solver), get_tree(solver), 0))
    return _find_next_complete_tree(solver, pq, iter)
end


"""
    Base.iterate(iter::TopDownIterator, pq::DataStructures.PriorityQueue)

Describes the iteration for a given [`TopDownIterator`](@ref) and a [`PriorityQueue`](@ref) over the grammar without enqueueing new items to the priority queue. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::FixedShapedIterator, pq::DataStructures.PriorityQueue)
    return _find_next_complete_tree(iter.solver, pq, iter)
end

"""
    _find_next_complete_tree(grammar::ContextSensitiveGrammar, max_depth::Int, max_size::Int, pq::PriorityQueue, iter::TopDownIterator)::Union{Tuple{RuleNode, PriorityQueue}, Nothing}

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
            # Fixed Shaped Hole was found
            # TODO: problem. this 'hole' is tied to a target state. it should be state independent
            (; hole, path) = hole_res
    
            for rule_index ∈ findall(hole.domain)
                state = save_state!(solver)
                fill_hole!(solver, path, rule_index)
                enqueue!(pq, get_state(solver), priority_function(iter, get_grammar(solver), get_tree(solver), priority_value))
                load_state!(solver, state)
            end
        end
    end
    return nothing
end
