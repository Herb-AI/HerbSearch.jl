"""
    abstract type TopDownSearchStrategy

Abstract super-type for all top down search strategies.
Each search strategy may overload any of the following methods:

- priority_function
- derivation_heuristic
- hole_heuristic
"""
abstract type TopDownSearchStrategy <: AbstractSearchStrategy end

"""
    priority_function(::TopDownSearchStrategy, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Assigns a priority value to a `tree` that needs to be considered later in the search. Trees with the lowest priority value are considered first.

- `g`: The grammar used for enumeration
- `tree`: The tree that is about to be stored in the priority queue
- `parent_value`: The priority value of the parent [`PriorityQueueItem`](@ref)
"""
function priority_function(
    ::TopDownSearchStrategy, 
    g::Grammar, 
    tree::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}}
)
    #the default priority function is the bfs priority function
    priority_function(BreadthFirstSearchStrategy, g, tree, parent_value);
end

"""
    derivation_heuristic(::TopDownSearchStrategy, nodes::Vector{AbstractRuleNode}, context::GrammarContext)::Vector{AbstractRuleNode})

Returns an ordered sublist of `nodes`, based on which ones are most promising to fill the hole at the given `context`.

- `nodes::Vector{RuleNode}`: a list of nodes the hole can be filled with
- `context::GrammarContext`: holds the location of the to be filled hole
"""
function derivation_heuristic(::TopDownSearchStrategy, nodes::Vector{RuleNode}, ::GrammarContext)::Vector{AbstractRuleNode}
    return nodes;
end

"""
    hole_heuristic(node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}

Defines a heuristic over holes. Returns a [`HoleReference`](@ref) once a hole is found. 
"""
function hole_heuristic(::TopDownSearchStrategy, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}
    return heuristic_leftmost(node, max_depth);
end

"""
    abstract type BreadthFirstSearchStrategy

Search strategy that will yield trees in the grammar in increasing order of size.
"""
struct BreadthFirstSearchStrategy <: TopDownSearchStrategy end

"""
    priority_function(::BreadthFirstSearchStrategy, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Assigns priority such that the search tree is traversed like in a BFS manner
"""
function priority_function(
    ::BreadthFirstSearchStrategy, 
    ::Grammar, 
    ::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}}
)
    parent_value + 1;
end

"""
    abstract type DepthFirstSearchStrategy

Search strategy that will yield trees in the grammar in decreasing order of size.
"""
struct DepthFirstSearchStrategy <: TopDownSearchStrategy end

"""
    priority_function(::DepthFirstSearchStrategy, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Assigns priority such that the search tree is traversed like in a DFS manner
"""
function priority_function(
    ::DepthFirstSearchStrategy, 
    ::Grammar, 
    ::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}}
)
    parent_value - 1;
end

"""
    abstract type MostLikelyFirstSearchStrategy

Returns an enumerator that enumerates expressions in the grammar in decreasing order of probability.
Only use this function with probabilistic grammars.
"""
struct MostLikelyFirstSearchStrategy <: TopDownSearchStrategy end

"""
    priority_function(::MostLikelyFirstSearchStrategy, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

Calculates logit for all possible derivations for a node in a tree and returns them.
"""
function priority_function(
    ::MostLikelyFirstSearchStrategy,
    g::ContextSensitiveGrammar, 
    tree::AbstractRuleNode, 
    ::Union{Real, Tuple{Vararg{Real}}}
)
    -rulenode_log_probability(tree, g)
end
