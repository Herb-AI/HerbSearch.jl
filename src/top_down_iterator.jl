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
    priority_function(::TopDownIterator, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Assigns a priority value to a `tree` that needs to be considered later in the search. Trees with the lowest priority value are considered first.

- `g`: The grammar used for enumeration
- `tree`: The tree that is about to be stored in the priority queue
- `parent_value`: The priority value of the parent [`State`](@ref)
"""
function priority_function(
    ::TopDownIterator, 
    g::Grammar, 
    tree::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}}
)
    #the default priority function is the bfs priority function
    priority_function(BFSIterator, g, tree, parent_value);
end

"""
    derivation_heuristic(::TopDownIterator, nodes::Vector{RuleNode}, ::GrammarContext)::Vector{AbstractRuleNode}

Returns an ordered sublist of `nodes`, based on which ones are most promising to fill the hole at the given `context`.

- `nodes::Vector{RuleNode}`: a list of nodes the hole can be filled with
- `context::GrammarContext`: holds the location of the to be filled hole
"""
function derivation_heuristic(::TopDownIterator, nodes::Vector{RuleNode}, ::GrammarContext)::Vector{AbstractRuleNode}
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
    priority_function(::BFSIterator, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Assigns priority such that the search tree is traversed like in a BFS manner
"""
function priority_function(
    ::BFSIterator, 
    ::Grammar, 
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
    priority_function(::DFSIterator, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Assigns priority such that the search tree is traversed like in a DFS manner
"""
function priority_function(
    ::DFSIterator, 
    ::Grammar, 
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
    priority_function(::MLFSIterator, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Calculates logit for all possible derivations for a node in a tree and returns them.
"""
function priority_function(
    ::MLFSIterator,
    g::Grammar, 
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

    #TODO: refactor this to the program iterator constructor
    iter.solver = Solver(iter.grammar, iter.sym)

    grammar, max_depth, max_size, sym = iter.grammar, iter.max_depth, iter.max_size, iter.sym

    enqueue!(pq, get_state(solver), priority_function(iter, grammar, init_node, 0))
    return _find_next_complete_tree(grammar, max_depth, max_size, pq, iter)
end


"""
    Base.iterate(iter::TopDownIterator, pq::DataStructures.PriorityQueue)

Describes the iteration for a given [`TopDownIterator`](@ref) and a [`PriorityQueue`](@ref) over the grammar without enqueueing new items to the priority queue. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::TopDownIterator, pq::DataStructures.PriorityQueue)
    grammar, max_depth, max_size = iter.grammar, iter.max_depth, iter.max_size

    return _find_next_complete_tree(grammar, max_depth, max_size, pq, iter)
end

"""
    _find_next_complete_tree(grammar::ContextSensitiveGrammar, max_depth::Int, max_size::Int, pq::PriorityQueue, iter::TopDownIterator)::Union{Tuple{RuleNode, PriorityQueue}, Nothing}

Takes a priority queue and returns the smallest AST from the grammar it can obtain from the queue or by (repeatedly) expanding trees that are in the queue.
Returns `nothing` if there are no trees left within the depth limit.
"""
function _find_next_complete_tree(
    grammar::ContextSensitiveGrammar, 
    max_depth::Int, 
    max_size::Int,
    pq::PriorityQueue,
    iter::TopDownIterator
)::Union{Tuple{RuleNode, PriorityQueue}, Nothing}
    while length(pq) ≠ 0
        (state, priority_value) = dequeue_pair!(pq)
        set_state!(solver, state)

        #TODO: handle complete states
        # if pqitem.complete
        #     return (pqitem.tree, pq)
        # end

        hole_res = hole_heuristic(iter, get_tree(solver), max_depth)
        if hole_res ≡ already_complete
            # TODO: this tree could have fixed shaped holes only and should be iterated differently (https://github.com/orgs/Herb-AI/projects/6/views/1?pane=issue&itemId=54384555)
            return (get_tree(solver), pq)
        elseif hole_res ≡ limit_reached
            # The maximum depth is reached
            continue
        elseif hole_res isa HoleReference
            # Variable Shaped Hole was found
            (; hole, path) = hole_res
    
            for domain ∈ partition(hole, grammar)
                state = save_state(solver)
                remove_all_but!(solver, hole_res, domain)
                enqueue!(pq, get_state(solver), priority_function(iter, grammar, expanded_tree, priority_value))
                load_state(state)
            end
    end
    return nothing
end
