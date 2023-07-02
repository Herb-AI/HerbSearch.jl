"""
Enumerates a context-free grammar up to a given depth in a breadth-first order.
This means that smaller programs are returned before larger programs.
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
Representation of the different reasons why expanding a partial tree failed. 
Currently, there are two possible causes of the expansion failing:

- `limit_reached`: The depth limit or the size limit of the partial tree would 
   be violated by the expansion
- `already_complete`: There is no hole left in the tree, so nothing can be 
   expanded.
"""
@enum ExpandFailureReason limit_reached=1 already_complete=2
@enum PropagateResult tree_complete=1 tree_incomplete=2 tree_infeasible=3

TreeConstraints = Tuple{AbstractRuleNode, Set{LocalConstraint}, PropagateResult}
IsValidTree = Bool

"""
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

PriorityQueueItem(tree::AbstractRuleNode, size::Int) = PriorityQueueItem(tree, size, [])


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


function Base.iterate(iter::ContextSensitivePriorityEnumerator, pq::DataStructures.PriorityQueue)
    grammar, max_depth, max_size = iter.grammar, iter.max_depth, iter.max_size
    priority_function, expand_function = iter.priority_function, iter.expand_function
    return _find_next_complete_tree(grammar, max_depth, max_size, priority_function, expand_function, pq)
end


IsInfeasible = Bool

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
Takes a priority queue and returns the smallest AST from the grammar it can obtain from the
queue or by (repeatedly) expanding trees that are in the queue.
Returns nothing if there are no trees left within the depth limit.
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
Recursive expand function used in multiple enumeration techniques.
Expands one hole/undefined leaf of the given RuleNode tree.
The first hole found using the given hole heuristic
If the expansion was successful, returns a list of new trees and a
list of lists of hole locations, corresponding to the holes of each
new expanded tree. 
Returns nothing if tree is already complete (contains no holes).
Returns empty list if the tree is partial (contains holes), 
    but they couldn't be expanded because of the depth limit.
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
