# """
#     mutable struct TopDownIterator <: ProgramIterator 

# Enumerates a context-free grammar starting at [`Symbol`](@ref) `sym` with respect to the grammar up to a given depth and a given size. 
# The exploration is done using the given priority function for derivations, and the expand function for discovered nodes.
# Concrete iterators may overload the following methods:
# - priority_function
# - derivation_heuristic
# - hole_heuristic
# """
# abstract type TopDownIterator <: ProgramIterator end

# """
#     priority_function(::TopDownIterator, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

# Assigns a priority value to a `tree` that needs to be considered later in the search. Trees with the lowest priority value are considered first.

# - `g`: The grammar used for enumeration
# - `tree`: The tree that is about to be stored in the priority queue
# - `parent_value`: The priority value of the parent [`PriorityQueueItem`](@ref)
# """
# function priority_function(
#     ::TopDownIterator, 
#     g::Grammar, 
#     tree::AbstractRuleNode, 
#     parent_value::Union{Real, Tuple{Vararg{Real}}}
# )
#     #the default priority function is the bfs priority function
#     priority_function(BFSIterator, g, tree, parent_value);
# end

# """
#     derivation_heuristic(::TopDownIterator, nodes::Vector{RuleNode}, ::GrammarContext)::Vector{AbstractRuleNode}

# Returns an ordered sublist of `nodes`, based on which ones are most promising to fill the hole at the given `context`.

# - `nodes::Vector{RuleNode}`: a list of nodes the hole can be filled with
# - `context::GrammarContext`: holds the location of the to be filled hole
# """
# function derivation_heuristic(::TopDownIterator, nodes::Vector{RuleNode}, ::GrammarContext)::Vector{AbstractRuleNode}
#     return nodes;
# end

# """
#     hole_heuristic(::TopDownIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}

# Defines a heuristic over holes. Returns a [`HoleReference`](@ref) once a hole is found. 
# """
# function hole_heuristic(::TopDownIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}
#     return heuristic_leftmost(node, max_depth);
# end


# Base.@doc """
#     @programiterator BFSIterator() <: TopDownIterator

# Returns a breadth-first iterator given a grammar and a starting symbol. Returns trees in the grammar in increasing order of size. Inherits all stop-criteria from TopDownIterator.
# """ BFSIterator
# @programiterator BFSIterator() <: TopDownIterator

# """
#     priority_function(::BFSIterator, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

# Assigns priority such that the search tree is traversed like in a BFS manner
# """
# function priority_function(
#     ::BFSIterator, 
#     ::Grammar, 
#     ::AbstractRuleNode, 
#     parent_value::Union{Real, Tuple{Vararg{Real}}}
# )
#     parent_value + 1;
# end


# Base.@doc """
#     @programiterator DFSIterator() <: TopDownIterator

# Returns a depth-first search enumerator given a grammar and a starting symbol. Returns trees in the grammar in decreasing order of size. Inherits all stop-criteria from TopDownIterator.
# """ DFSIterator
# @programiterator DFSIterator() <: TopDownIterator

# """
#     priority_function(::DFSIterator, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

# Assigns priority such that the search tree is traversed like in a DFS manner
# """
# function priority_function(
#     ::DFSIterator, 
#     ::Grammar, 
#     ::AbstractRuleNode, 
#     parent_value::Union{Real, Tuple{Vararg{Real}}}
# )
#     parent_value - 1;
# end


# Base.@doc """
#     @programiterator MLFSIterator() <: TopDownIterator

# Iterator that enumerates expressions in the grammar in decreasing order of probability (Only use this iterator with probabilistic grammars). Inherits all stop-criteria from TopDownIterator.
# """ MLFSIterator
# @programiterator MLFSIterator() <: TopDownIterator

# """
#     priority_function(::MLFSIterator, g::Grammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}})

# Calculates logit for all possible derivations for a node in a tree and returns them.
# """
# function priority_function(
#     ::MLFSIterator,
#     g::Grammar, 
#     tree::AbstractRuleNode, 
#     ::Union{Real, Tuple{Vararg{Real}}}
# )
#     -rulenode_log_probability(tree, g)
# end

# """
#     @enum ExpandFailureReason limit_reached=1 already_complete=2

# Representation of the different reasons why expanding a partial tree failed. 
# Currently, there are two possible causes of the expansion failing:

# - `limit_reached`: The depth limit or the size limit of the partial tree would 
#    be violated by the expansion
# - `already_complete`: There is no hole left in the tree, so nothing can be 
#    expanded.
# """
# @enum ExpandFailureReason limit_reached=1 already_complete=2


# """
#     @enum PropagateResult tree_complete=1 tree_incomplete=2 tree_infeasible=3

# Representation of the possible results of a constraint propagation. 
# At the moment there are three possible outcomes:

# - `tree_complete`: The propagation was applied successfully and the tree does not contain any holes anymore. Thus no constraints can be applied anymore.
# - `tree_incomplete`: The propagation was applied successfully and the tree does contain more holes. Thus more constraints may be applied to further prune the respective domains.
# - `tree_infeasible`: The propagation was succesful, but there are holes with empty domains. Hence, the tree is now infeasible.
# """
# @enum PropagateResult tree_complete=1 tree_incomplete=2 tree_infeasible=3

# TreeConstraints = Tuple{AbstractRuleNode, Set{LocalConstraint}, PropagateResult}
# IsValidTree = Bool

# """
#     struct PriorityQueueItem 

# Represents an item in the priority enumerator priority queue.
# An item contains of:

# - `tree`: A partial AST
# - `size`: The size of the tree. This is a cached value which prevents
#    having to traverse the entire tree each time the size is needed.
# - `constraints`: The local constraints that apply to this tree. 
#    These constraints are enforced each time the tree is modified.
# """
# struct PriorityQueueItem 
#     tree::AbstractRuleNode
#     size::Int
#     constraints::Set{LocalConstraint}
#     complete::Bool
# end

# """
#     PriorityQueueItem(tree::AbstractRuleNode, size::Int)

# Constructs [`PriorityQueueItem`](@ref) given only a tree and the size, but no constraints.
# """
# PriorityQueueItem(tree::AbstractRuleNode, size::Int) = PriorityQueueItem(tree, size, [])


# """
#     Base.iterate(iter::TopDownIterator)

# Describes the iteration for a given [`TopDownIterator`](@ref) over the grammar. The iteration constructs a [`PriorityQueue`](@ref) first and then prunes it propagating the active constraints. Recursively returns the result for the priority queue.
# """
# function Base.iterate(iter::TopDownIterator)
#     # Priority queue with number of nodes in the program
#     pq :: PriorityQueue{PriorityQueueItem, Union{Real, Tuple{Vararg{Real}}}} = PriorityQueue()

#     grammar, max_depth, max_size, sym = iter.grammar, iter.max_depth, iter.max_size, iter.sym

#     init_node = Hole(get_domain(grammar, sym))

#     propagate_result, new_constraints = propagate_constraints(init_node, grammar, Set{LocalConstraint}(), max_size)
#     if propagate_result == tree_infeasible return end
#     enqueue!(pq, PriorityQueueItem(init_node, 0, new_constraints, propagate_result == tree_complete), priority_function(iter, grammar, init_node, 0))
    
#     return _find_next_complete_tree(grammar, max_depth, max_size, pq, iter)
# end


# """
#     Base.iterate(iter::TopDownIterator, pq::DataStructures.PriorityQueue)

# Describes the iteration for a given [`TopDownIterator`](@ref) and a [`PriorityQueue`](@ref) over the grammar without enqueueing new items to the priority queue. Recursively returns the result for the priority queue.
# """
# function Base.iterate(iter::TopDownIterator, pq::DataStructures.PriorityQueue)
#     grammar, max_depth, max_size = iter.grammar, iter.max_depth, iter.max_size

#     return _find_next_complete_tree(grammar, max_depth, max_size, pq, iter)
# end


# IsInfeasible = Bool

# """
#     function propagate_constraints(root::AbstractRuleNode, grammar::ContextSensitiveGrammar, local_constraints::Set{LocalConstraint}, max_holes::Int, filled_hole::Union{HoleReference, Nothing}=nothing)::Tuple{PropagateResult, Set{LocalConstraint}}

# Propagates a set of local constraints recursively to all children of a given root node. As `propagate_constraints` gets often called when a hole was just filled, `filled_hole` helps keeping track to propagate the constraints to relevant nodes, e.g. children of `filled_hole`. `max_holes` makes sure that `max_size` of [`Base.iterate`](@ref) is not violated. 
# The function returns the [`PropagateResult`](@ref) and the set of relevant [`LocalConstraint`](@ref)s.
# """
# function propagate_constraints(
#     root::AbstractRuleNode,
#     grammar::ContextSensitiveGrammar,
#     local_constraints::Set{LocalConstraint},
#     max_holes::Int,
#     filled_hole::Union{HoleReference, Nothing}=nothing,
# )::Tuple{PropagateResult, Set{LocalConstraint}}
#     new_local_constraints = Set()

#     found_holes = 0

#     function dfs(node::RuleNode, path::Vector{Int})::IsInfeasible
#         node.children = copy(node.children)

#         for i in eachindex(node.children)
#             new_path = push!(copy(path), i)
#             node.children[i] = copy(node.children[i])
#             if dfs(node.children[i], new_path) return true end
#         end

#         return false
#     end

#     function dfs(hole::Hole, path::Vector{Int})::IsInfeasible
#         found_holes += 1
#         if found_holes > max_holes return true end

#         context = GrammarContext(root, path, local_constraints)
#         new_domain = findall(hole.domain)

#         # Local constraints that are specific to this rulenode
#         for constraint ∈ context.constraints
#             curr_domain, curr_local_constraints = propagate(constraint, grammar, context, new_domain, filled_hole)
#             !isa(curr_domain, PropagateFailureReason) && (new_domain = curr_domain)
#             (new_domain == []) && (return true)
#             union!(new_local_constraints, curr_local_constraints)
#         end

#         # General constraints for the entire grammar
#         for constraint ∈ grammar.constraints
#             curr_domain, curr_local_constraints = propagate(constraint, grammar, context, new_domain, filled_hole)
#             !isa(curr_domain, PropagateFailureReason) && (new_domain = curr_domain)
#             (new_domain == []) && (return true)
#             union!(new_local_constraints, curr_local_constraints)
#         end

#         for r ∈ 1:length(grammar.rules)
#             hole.domain[r] = r ∈ new_domain
#         end

#         return false
#     end

#     if dfs(root, Vector{Int}()) return tree_infeasible, Set() end

#     return found_holes == 0 ? tree_complete : tree_incomplete, new_local_constraints
# end

# item = 0

# """
#     _find_next_complete_tree(grammar::ContextSensitiveGrammar, max_depth::Int, max_size::Int, pq::PriorityQueue, iter::TopDownIterator)::Union{Tuple{RuleNode, PriorityQueue}, Nothing}

# Takes a priority queue and returns the smallest AST from the grammar it can obtain from the queue or by (repeatedly) expanding trees that are in the queue.
# Returns `nothing` if there are no trees left within the depth limit.
# """
# function _find_next_complete_tree(
#     grammar::ContextSensitiveGrammar, 
#     max_depth::Int, 
#     max_size::Int,
#     pq::PriorityQueue,
#     iter::TopDownIterator
# )::Union{Tuple{RuleNode, PriorityQueue}, Nothing}
#     while length(pq) ≠ 0

#         (pqitem, priority_value) = dequeue_pair!(pq)
#         if pqitem.complete
#             return (pqitem.tree, pq)
#         end

#         # We are about to fill a hole, so the remaining #holes that are allowed in propagation, should be 1 fewer
#         expand_result = _expand(pqitem.tree, grammar, max_depth, max_size - pqitem.size - 1, GrammarContext(pqitem.tree, [], pqitem.constraints), iter)

#         if expand_result ≡ already_complete
#             # Current tree is complete, it can be returned
#             return (priority_queue_item.tree, pq)
#         elseif expand_result ≡ limit_reached
#             # The maximum depth is reached
#             continue
#         elseif expand_result isa Vector{TreeConstraints}
#             # Either the current tree can't be expanded due to depth 
#             # limit (no expanded trees), or the expansion was successful. 
#             # We add the potential expanded trees to the pq and move on to 
#             # the next tree in the queue.

#             for (expanded_tree, local_constraints, propagate_result) ∈ expand_result
#                 # expanded_tree is a new program tree with a new expanded child compared to pqitem.tree
#                 # new_holes are all the holes in expanded_tree
#                 new_pqitem = PriorityQueueItem(expanded_tree, pqitem.size + 1, local_constraints, propagate_result == tree_complete)
#                 enqueue!(pq, new_pqitem, priority_function(iter, grammar, expanded_tree, priority_value))
#             end
#         else
#             error("Got an invalid response of type $(typeof(expand_result)) from expand function")
#         end
#     end
#     return nothing
# end

# """
#     _expand(root::RuleNode, grammar::ContextSensitiveGrammar, max_depth::Int, max_holes::Int, context::GrammarContext, iter::TopDownIterator)::Union{ExpandFailureReason, Vector{TreeConstraints}}

# Recursive expand function used in multiple enumeration techniques.
# Expands one hole/undefined leaf of the given RuleNode tree found using the given hole heuristic.
# If the expansion was successful, returns a list of new trees and a list of lists of hole locations, corresponding to the holes of each newly expanded tree. 
# Returns `nothing` if tree is already complete (i.e. contains no holes).
# Returns an empty list if the tree is partial (i.e. contains holes), but they could not be expanded because of the depth limit.
# """
# function _expand(
#         root::RuleNode, 
#         grammar::ContextSensitiveGrammar, 
#         max_depth::Int, 
#         max_holes::Int,
#         context::GrammarContext,
#         iter::TopDownIterator
#     )::Union{ExpandFailureReason, Vector{TreeConstraints}}
#     hole_res = hole_heuristic(iter, root, max_depth)
#     if hole_res isa ExpandFailureReason
#         return hole_res
#     elseif hole_res isa HoleReference
#         # Hole was found
#         (; hole, path) = hole_res
#         hole_context = GrammarContext(context.originalExpr, path, context.constraints)
#         expanded_child_trees = _expand(hole, grammar, max_depth, max_holes, hole_context, iter)

#         nodes::Vector{TreeConstraints} = []
#         for (expanded_tree, local_constraints) ∈ expanded_child_trees
#             copied_root = copy(root)

#             # Copy only the path in question instead of deepcopying the entire tree
#             curr_node = copied_root
#             for p in path
#                 curr_node.children = copy(curr_node.children)
#                 curr_node.children[p] = copy(curr_node.children[p])
#                 curr_node = curr_node.children[p]
#             end

#             parent_node = get_node_at_location(copied_root, path[1:end-1])
#             parent_node.children[path[end]] = expanded_tree

#             propagate_result, new_local_constraints = propagate_constraints(copied_root, grammar, local_constraints, max_holes, hole_res)
#             if propagate_result == tree_infeasible continue end
#             push!(nodes, (copied_root, new_local_constraints, propagate_result))
#         end
        
#         return nodes
#     else
#         error("Got an invalid response of type $(typeof(expand_result)) from `hole_heuristic` function")
#     end
# end


# """
#     _expand(node::Hole, grammar::ContextSensitiveGrammar, ::Int, max_holes::Int, context::GrammarContext, iter::TopDownIterator)::Union{ExpandFailureReason, Vector{TreeConstraints}}

# Expands a given hole that was found in [`_expand`](@ref) using the given derivation heuristic. Returns the list of discovered nodes in that order and with their respective constraints.
# """
# function _expand(
#     node::Hole, 
#     grammar::ContextSensitiveGrammar, 
#     ::Int, 
#     max_holes::Int,
#     context::GrammarContext,
#     iter::TopDownIterator
# )::Union{ExpandFailureReason, Vector{TreeConstraints}}
#     nodes::Vector{TreeConstraints} = []
    
#     new_nodes = map(i -> RuleNode(i, grammar), findall(node.domain))
#     for new_node ∈ derivation_heuristic(iter, new_nodes, context)

#         # If dealing with the root of the tree, propagate here
#         if context.nodeLocation == []
#             propagate_result, new_local_constraints = propagate_constraints(new_node, grammar, context.constraints, max_holes, HoleReference(node, []))
#             if propagate_result == tree_infeasible continue end
#             push!(nodes, (new_node, new_local_constraints, propagate_result))
#         else
#             push!(nodes, (new_node, context.constraints, tree_incomplete))
#         end

#     end


#     return nodes
# end
