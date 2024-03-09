"""
    mutable struct TopDownIterator <: ProgramIterator 

Enumerates a context-free grammar starting at [`Symbol`](@ref) `sym` with respect to the grammar up to a given depth and a given size. 
The exploration is done using the given priority function for derivations, and the expand function for discovered nodes.
Concrete iterators may overload the following methods:
- priority_function
- derivation_heuristic
- hole_heuristic
"""
abstract type TopDownIterator <: ProgramIterator end

"""
    priority_function(::TopDownIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Assigns a priority value to a `tree` that needs to be considered later in the search. Trees with the lowest priority value are considered first.

- `g`: The grammar used for enumeration
- `tree`: The tree that is about to be stored in the priority queue
- `parent_value`: The priority value of the parent [`State`](@ref)
"""
function priority_function(
    ::TopDownIterator, 
    g::AbstractGrammar, 
    tree::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}}
)
    #the default priority function is the bfs priority function
    priority_function(BFSIterator, g, tree, parent_value);
end

"""
    derivation_heuristic(::TopDownIterator, nodes::Vector{RuleNode})::Vector{AbstractRuleNode}

Returns an ordered sublist of `nodes`, based on which ones are most promising to fill the hole at the given `context`.

- `nodes::Vector{RuleNode}`: a list of nodes the hole can be filled with
"""
function derivation_heuristic(::TopDownIterator, nodes::Vector{RuleNode})::Vector{AbstractRuleNode}
    return nodes;
end

"""
    hole_heuristic(::TopDownIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}

Defines a heuristic over variable shaped holes. Returns a [`HoleReference`](@ref) once a hole is found.
"""
function hole_heuristic(::TopDownIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}
    return heuristic_leftmost(node, max_depth);
end


Base.@doc """
    @programiterator BFSIterator() <: TopDownIterator

Returns a breadth-first iterator given a grammar and a starting symbol. Returns trees in the grammar in increasing order of size. Inherits all stop-criteria from TopDownIterator.
""" BFSIterator
@programiterator BFSIterator() <: TopDownIterator

"""
    priority_function(::BFSIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Assigns priority such that the search tree is traversed like in a BFS manner
"""
function priority_function(
    ::BFSIterator, 
    ::AbstractGrammar, 
    ::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}}
)
    parent_value + 1;
end


Base.@doc """
    @programiterator DFSIterator() <: TopDownIterator

Returns a depth-first search enumerator given a grammar and a starting symbol. Returns trees in the grammar in decreasing order of size. Inherits all stop-criteria from TopDownIterator.
""" DFSIterator
@programiterator DFSIterator() <: TopDownIterator

"""
    priority_function(::DFSIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Assigns priority such that the search tree is traversed like in a DFS manner
"""
function priority_function(
    ::DFSIterator, 
    ::AbstractGrammar, 
    ::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}}
)
    parent_value - 1;
end


Base.@doc """
    @programiterator MLFSIterator() <: TopDownIterator

Iterator that enumerates expressions in the grammar in decreasing order of probability (Only use this iterator with probabilistic grammars). Inherits all stop-criteria from TopDownIterator.
""" MLFSIterator
@programiterator MLFSIterator() <: TopDownIterator

"""
    priority_function(::MLFSIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Calculates logit for all possible derivations for a node in a tree and returns them.
"""
function priority_function(
    ::MLFSIterator,
    g::AbstractGrammar, 
    tree::AbstractRuleNode, 
    ::Union{Real, Tuple{Vararg{Real}}}
)
    -rulenode_log_probability(tree, g)
end

"""
    @enum ExpandFailureReason limit_reached=1 already_complete=2

Representation of the different reasons why expanding a partial tree failed. 
Currently, there are two possible causes of the expansion failing:

- `limit_reached`: The depth limit or the size limit of the partial tree would 
   be violated by the expansion
- `already_complete`: There is no hole left in the tree, so nothing can be 
   expanded.
"""
@enum ExpandFailureReason limit_reached=1 already_complete=2

"""
    Base.iterate(iter::TopDownIterator)

Describes the iteration for a given [`TopDownIterator`](@ref) over the grammar. The iteration constructs a [`PriorityQueue`](@ref) first and then prunes it propagating the active constraints. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::TopDownIterator)
    # Priority queue with number of nodes in the program
    pq :: PriorityQueue{State, Union{Real, Tuple{Vararg{Real}}}} = PriorityQueue()

    #TODO: these attributes should be part of the solver, not of the iterator
    solver = iter.solver
    solver.max_size = iter.max_size
    solver.max_depth = iter.max_depth

    enqueue!(pq, get_state(solver), priority_function(iter, get_grammar(solver), get_tree(solver), 0))
    return _find_next_complete_tree(iter.solver, pq, iter)
end


# """
#     Base.iterate(iter::TopDownIterator, pq::DataStructures.PriorityQueue)

# Describes the iteration for a given [`TopDownIterator`](@ref) and a [`PriorityQueue`](@ref) over the grammar without enqueueing new items to the priority queue. Recursively returns the result for the priority queue.
# """
# function Base.iterate(iter::TopDownIterator, pq::DataStructures.PriorityQueue)
#     solver, max_depth, max_size = iter.solver, iter.max_depth, iter.max_size

#     return _find_next_complete_tree(solver, max_depth, max_size, pq, iter)
# end

"""
    Base.iterate(iter::TopDownIterator, pq::DataStructures.PriorityQueue)

Describes the iteration for a given [`TopDownIterator`](@ref) and a [`PriorityQueue`](@ref) over the grammar without enqueueing new items to the priority queue. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::TopDownIterator, tup::Tuple{Vector{AbstractRuleNode}, DataStructures.PriorityQueue})
    track!(iter.solver.statistics, "#CompleteTrees")
    if !isempty(tup[1])
        return (pop!(tup[1]), tup)
    end

    return _find_next_complete_tree(iter.solver, tup[2], iter)
end

"""
    _find_next_complete_tree(solver::Solver, pq::PriorityQueue, iter::TopDownIterator)::Union{Tuple{RuleNode, Tuple{Vector{AbstractRuleNode}, PriorityQueue}}, Nothing}

Takes a priority queue and returns the smallest AST from the grammar it can obtain from the queue or by (repeatedly) expanding trees that are in the queue.
Returns `nothing` if there are no trees left within the depth limit.
"""
function _find_next_complete_tree(
    solver::Solver,
    pq::PriorityQueue,
    iter::TopDownIterator
)::Union{Tuple{RuleNode, Tuple{Vector{AbstractRuleNode}, PriorityQueue}}, Nothing}
    while length(pq) ≠ 0
        (state, priority_value) = dequeue_pair!(pq)
        load_state!(solver, state)

        hole_res = hole_heuristic(iter, get_tree(solver), get_max_depth(solver))
        if hole_res ≡ already_complete
            # TODO: this tree could have fixed shaped holes only and should be iterated differently (https://github.com/orgs/Herb-AI/projects/6/views/1?pane=issue&itemId=54384555)
            fixed_shaped_iter = FixedShapedIterator(get_grammar(solver), :StartingSymbolIsIgnored, solver=solver)
            track!(solver.statistics, "#FixedShapedTrees")
            complete_trees = collect(fixed_shaped_iter)
            if !isempty(complete_trees)
                return (pop!(complete_trees), (complete_trees, pq))
            end
        elseif hole_res ≡ limit_reached
            # The maximum depth is reached
            continue
        elseif hole_res isa HoleReference
            # Variable Shaped Hole was found
            # TODO: problem. this 'hole' is tied to a target state. it should be state independent, so we only use the `path`
            (; hole, path) = hole_res
    
            partitioned_domains = partition(hole, get_grammar(solver))
            number_of_domains = length(partitioned_domains)
            for (i, domain) ∈ enumerate(partitioned_domains)
                if i < number_of_domains
                    state = save_state!(solver)
                end
                remove_all_but!(solver, path, domain)
                if is_feasible(solver)
                    enqueue!(pq, get_state(solver), priority_function(iter, get_grammar(solver), get_tree(solver), priority_value))
                end
                if i < number_of_domains
                    load_state!(solver, state)
                end
            end
        end
    end
    return nothing
end
