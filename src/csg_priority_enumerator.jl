"""
    mutable struct ContextSensitivePriorityEnumerator <: ExpressionIterator 

Enumerates a context-free grammar starting at [`Symbol`](@ref) `sym` with respect to the grammar up to a given depth and a given size. The exploration is done using the given priority function for derivations, and the expand function for discovered nodes.
"""
struct ContextSensitivePriorityEnumerator <: ExpressionIterator 
    grammar::ContextSensitiveGrammar
    max_depth::Int
    max_size::Int
    # Assigns a priority to a (partial or complete) tree.
    priority_function::Function
    # Expands a partial tree.
    expand_function::Function
    sym::Symbol
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
    @enum PropagateResult tree_complete=1 tree_incomplete=2 tree_infeasible=3

Representation of the possible results of a constraint propagation. 
At the moment there are three possible outcomes:

- `tree_complete`: The propagation was applied successfully and the tree does not contain any holes anymore. Thus no constraints can be applied anymore.
- `tree_incomplete`: The propagation was applied successfully and the tree does contain more holes. Thus more constraints may be applied to further prune the respective domains.
- `tree_infeasible`: The propagation was succesful, but there are holes with empty domains. Hence, the tree is now infeasible.
"""
@enum PropagateResult tree_complete=1 tree_incomplete=2 tree_infeasible=3

TreeConstraints = Tuple{AbstractRuleNode, Set{LocalConstraint}, PropagateResult}
IsValidTree = Bool

"""
    struct PriorityQueueItem 

Represents an item in the priority enumerator priority queue.
An item contains of:

- `tree`: A partial AST
- `size`: The size of the tree. This is a cached value which prevents
   having to traverse the entire tree each time the size is needed.
- `constraints`: The local constraints that apply to this tree. 
   These constraints are enforced each time the tree is modified.
"""
struct PriorityQueueItem 
    tree::AbstractRuleNode
    size::Int
    constraints::Set{LocalConstraint}
    complete::Bool
end

"""
    PriorityQueueItem(tree::AbstractRuleNode, size::Int)

Constructs [`PriorityQueueItem`](@ref) given only a tree and the size, but no constraints.
"""
PriorityQueueItem(tree::AbstractRuleNode, size::Int) = PriorityQueueItem(tree, size, [])


"""
    Base.iterate(iter::ContextSensitivePriorityEnumerator)

Describes the iteration for a given [`ContextSensitivePriorityEnumerator`](@ref) over the grammar. The iteration constructs a [`PriorityQueue`](@ref) first and then prunes it propagating the active constraints. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::ContextSensitivePriorityEnumerator)
    # Priority queue with number of nodes in the program
    pq :: PriorityQueue{PriorityQueueItem, Union{Real, Tuple{Vararg{Real}}}} = PriorityQueue()

    grammar, max_depth, max_size, sym = iter.grammar, iter.max_depth, iter.max_size, iter.sym
    priority_function, expand_function = iter.priority_function, iter.expand_function

    init_node = Hole(get_domain(grammar, sym))

    propagate_result, new_constraints = propagate_constraints(init_node, grammar, Set{LocalConstraint}(), max_size)
    if propagate_result == tree_infeasible return end
    enqueue!(pq, PriorityQueueItem(init_node, 0, new_constraints, propagate_result == tree_complete), priority_function(grammar, init_node, 0))
    
    return _find_next_complete_tree(grammar, max_depth, max_size, priority_function, expand_function, pq)
end


"""
    Base.iterate(iter::ContextSensitivePriorityEnumerator, pq::DataStructures.PriorityQueue)

Describes the iteration for a given [`ContextSensitivePriorityEnumerator`](@ref) and a [`PriorityQueue`](@ref) over the grammar without enqueueing new items to the priority queue. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::ContextSensitivePriorityEnumerator, pq::DataStructures.PriorityQueue)
    grammar, max_depth, max_size = iter.grammar, iter.max_depth, iter.max_size
    priority_function, expand_function = iter.priority_function, iter.expand_function
    return _find_next_complete_tree(grammar, max_depth, max_size, priority_function, expand_function, pq)
end


IsInfeasible = Bool

"""
    function propagate_constraints(root::AbstractRuleNode, grammar::ContextSensitiveGrammar, local_constraints::Set{LocalConstraint}, max_holes::Int, filled_hole::Union{HoleReference, Nothing}=nothing)::Tuple{PropagateResult, Set{LocalConstraint}}

Propagates a set of local constraints recursively to all children of a given root node. As `propagate_constraints` gets often called when a hole was just filled, `filled_hole` helps keeping track to propagate the constraints to relevant nodes, e.g. children of `filled_hole`. `max_holes` makes sure that `max_size` of [`Base.iterate`](@ref) is not violated. 
The function returns the [`PropagateResult`](@ref) and the set of relevant [`LocalConstraint`](@ref)s.
"""
function propagate_constraints(
    root::AbstractRuleNode,
    grammar::ContextSensitiveGrammar,
    local_constraints::Set{LocalConstraint},
    max_holes::Int,
    filled_hole::Union{HoleReference, Nothing}=nothing,
)::Tuple{PropagateResult, Set{LocalConstraint}}
    new_local_constraints = Set()

    found_holes = 0

    function dfs(node::RuleNode, path::Vector{Int})::IsInfeasible
        node.children = copy(node.children)

        for i in eachindex(node.children)
            new_path = push!(copy(path), i)
            node.children[i] = copy(node.children[i])
            if dfs(node.children[i], new_path) return true end
        end

        return false
    end

    function dfs(hole::Hole, path::Vector{Int})::IsInfeasible
        found_holes += 1
        if found_holes > max_holes return true end

        context = GrammarContext(root, path, local_constraints)
        new_domain = findall(hole.domain)

        # Local constraints that are specific to this rulenode
        for constraint ∈ context.constraints
            curr_domain, curr_local_constraints = propagate(constraint, grammar, context, new_domain, filled_hole)
            !isa(curr_domain, PropagateFailureReason) && (new_domain = curr_domain)
            (new_domain == []) && (return true)
            union!(new_local_constraints, curr_local_constraints)
        end

        # General constraints for the entire grammar
        for constraint ∈ grammar.constraints
            curr_domain, curr_local_constraints = propagate(constraint, grammar, context, new_domain, filled_hole)
            !isa(curr_domain, PropagateFailureReason) && (new_domain = curr_domain)
            (new_domain == []) && (return true)
            union!(new_local_constraints, curr_local_constraints)
        end

        for r ∈ 1:length(grammar.rules)
            hole.domain[r] = r ∈ new_domain
        end

        return false
    end

    if dfs(root, Vector{Int}()) return tree_infeasible, Set() end

    return found_holes == 0 ? tree_complete : tree_incomplete, new_local_constraints
end

item = 0

"""
    _find_next_complete_tree(grammar::ContextSensitiveGrammar, max_depth::Int, max_size::Int, priority_function::Function, expand_function::Function, pq::PriorityQueue)::Union{Tuple{RuleNode, PriorityQueue}, Nothing}

Takes a priority queue and returns the smallest AST from the grammar it can obtain from the queue or by (repeatedly) expanding trees that are in the queue.
Returns `nothing` if there are no trees left within the depth limit.
"""
function _find_next_complete_tree(
    grammar::ContextSensitiveGrammar, 
    max_depth::Int, 
    max_size::Int,
    priority_function::Function, 
    expand_function::Function, 
    pq::PriorityQueue
)::Union{Tuple{RuleNode, PriorityQueue}, Nothing}
    while length(pq) ≠ 0

        (pqitem, priority_value) = dequeue_pair!(pq)
        if pqitem.complete
            return (pqitem.tree, pq)
        end

        # We are about to fill a hole, so the remaining #holes that are allowed in propagation, should be 1 fewer
        expand_result = expand_function(pqitem.tree, grammar, max_depth, max_size - pqitem.size - 1, GrammarContext(pqitem.tree, [], pqitem.constraints))
          
        if expand_result ≡ already_complete
            # Current tree is complete, it can be returned
            return (priority_queue_item.tree, pq)
        elseif expand_result ≡ limit_reached
            # The maximum depth is reached
            continue
        elseif expand_result isa Vector{TreeConstraints}
            # Either the current tree can't be expanded due to depth 
            # limit (no expanded trees), or the expansion was successful. 
            # We add the potential expanded trees to the pq and move on to 
            # the next tree in the queue.

            for (expanded_tree, local_constraints, propagate_result) ∈ expand_result
                # expanded_tree is a new program tree with a new expanded child compared to pqitem.tree
                # new_holes are all the holes in expanded_tree
                new_pqitem = PriorityQueueItem(expanded_tree, pqitem.size + 1, local_constraints, propagate_result == tree_complete)
                enqueue!(pq, new_pqitem, priority_function(grammar, expanded_tree, priority_value))
            end
        else
            error("Got an invalid response of type $(typeof(expand_result)) from expand function")
        end
    end
    return nothing
end

"""
    _expand(root::RuleNode, grammar::ContextSensitiveGrammar, max_depth::Int, max_holes::Int, context::GrammarContext, hole_heuristic::Function, derivation_heuristic::Function)::Union{ExpandFailureReason, Vector{TreeConstraints}}

Recursive expand function used in multiple enumeration techniques.
Expands one hole/undefined leaf of the given RuleNode tree found using the given hole heuristic.
If the expansion was successful, returns a list of new trees and a list of lists of hole locations, corresponding to the holes of each newly expanded tree. 
Returns `nothing` if tree is already complete (i.e. contains no holes).
Returns an empty list if the tree is partial (i.e. contains holes), but they could not be expanded because of the depth limit.
"""
function _expand(
        root::RuleNode, 
        grammar::ContextSensitiveGrammar, 
        max_depth::Int, 
        max_holes::Int,
        context::GrammarContext, 
        hole_heuristic::Function,
        derivation_heuristic::Function,
    )::Union{ExpandFailureReason, Vector{TreeConstraints}}
    hole_res = hole_heuristic(root, max_depth)
    if hole_res isa ExpandFailureReason
        return hole_res
    elseif hole_res isa HoleReference
        # Hole was found
        (; hole, path) = hole_res
        hole_context = GrammarContext(context.originalExpr, path, context.constraints)
        expanded_child_trees = _expand(hole, grammar, max_depth, max_holes, hole_context, hole_heuristic, derivation_heuristic)

        nodes::Vector{TreeConstraints} = []
        for (expanded_tree, local_constraints) ∈ expanded_child_trees
            copied_root = copy(root)

            # Copy only the path in question instead of deepcopying the entire tree
            curr_node = copied_root
            for p in path
                curr_node.children = copy(curr_node.children)
                curr_node.children[p] = copy(curr_node.children[p])
                curr_node = curr_node.children[p]
            end

            parent_node = get_node_at_location(copied_root, path[1:end-1])
            parent_node.children[path[end]] = expanded_tree

            propagate_result, new_local_constraints = propagate_constraints(copied_root, grammar, local_constraints, max_holes, hole_res)
            if propagate_result == tree_infeasible continue end
            push!(nodes, (copied_root, new_local_constraints, propagate_result))
        end
        
        return nodes
    else
        error("Got an invalid response of type $(typeof(expand_result)) from `hole_heuristic` function")
    end
end


"""
    _expand(node::Hole, grammar::ContextSensitiveGrammar, ::Int, max_holes::Int, context::GrammarContext, hole_heuristic::Function, derivation_heuristic::Function)::Union{ExpandFailureReason, Vector{TreeConstraints}}

Expands a given hole that was found in [`_expand`](@ref) using the given derivation heuristic. Returns the list of discovered nodes in that order and with their respective constraints.
"""
function _expand(
    node::Hole, 
    grammar::ContextSensitiveGrammar, 
    ::Int, 
    max_holes::Int,
    context::GrammarContext, 
    hole_heuristic::Function,
    derivation_heuristic::Function,
)::Union{ExpandFailureReason, Vector{TreeConstraints}}
    nodes::Vector{TreeConstraints} = []
    
    for rule_index ∈ derivation_heuristic(findall(node.domain), context)
        new_node = RuleNode(rule_index, grammar)

        # If dealing with the root of the tree, propagate here
        if context.nodeLocation == []
            propagate_result, new_local_constraints = propagate_constraints(new_node, grammar, context.constraints, max_holes, HoleReference(node, []))
            if propagate_result == tree_infeasible continue end
            push!(nodes, (new_node, new_local_constraints, propagate_result))
        else
            push!(nodes, (new_node, context.constraints, tree_incomplete))
        end

    end


    return nodes
end
