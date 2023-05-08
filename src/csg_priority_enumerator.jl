"""
Enumerates a context-free grammar up to a given depth in a breadth-first order.
This means that smaller programs are returned before larger programs.
"""
mutable struct ContextSensitivePriorityEnumerator <: ExpressionIterator 
    grammar::ContextSensitiveGrammar
    max_depth::Int
    max_size::Int
    # Assigns a priority to a (partial or complete) tree.
    priority_function::Function
    # Expands a partial tree.
    expand_function::Function
    sym::Symbol
end 

@enum ExpandFailureReason limit_reached=1 already_complete=2

struct PQItem 
    tree::AbstractRuleNode
    size::Int
    constraints::Vector{LocalConstraint}
end
PQItem(tree::AbstractRuleNode, size::Int) = PQItem(tree, size, [])

function Base.iterate(iter::ContextSensitivePriorityEnumerator)
    # Priority queue with number of nodes in the program
    pq :: PriorityQueue{PQItem, Union{Real, Tuple{Vararg{Real}}}} = PriorityQueue()

    grammar, max_depth, max_size, sym = iter.grammar, iter.max_depth, iter.max_size, iter.sym
    priority_function, expand_function = iter.priority_function, iter.expand_function

    init_node = Hole(get_domain(grammar, sym))

    enqueue!(pq, PQItem(init_node, 0), priority_function(grammar, init_node, 0))
    
    return _find_next_complete_tree(grammar, max_depth, max_size, priority_function, expand_function, pq)
end


function Base.iterate(iter::ContextSensitivePriorityEnumerator, pq::DataStructures.PriorityQueue)
    grammar, max_depth, max_size = iter.grammar, iter.max_depth, iter.max_size
    priority_function, expand_function = iter.priority_function, iter.expand_function
    return _find_next_complete_tree(grammar, max_depth, max_size, priority_function, expand_function, pq)
end


"""
Reduces the set of possible children of a node using the grammar's constraints
"""
function propagate_constraints(
        grammar::ContextSensitiveGrammar, 
        context::GrammarContext, 
        child_rules::Vector{Int}
    )::Tuple
    domain = child_rules
    new_local_constraints::Vector{LocalConstraint} = []

    # Local constraints that are specific to this rulenode
    for constraint ∈ context.constraints
        domain, local_constraints = propagate(constraint, grammar, context, domain)
        domain == [] && return domain, []
        # TODO: Should we check for duplicates?
        append!(new_local_constraints, local_constraints)
    end

    # General constraints for the entire grammar
    for constraint ∈ grammar.constraints
        domain, local_constraints = propagate(constraint, grammar, context, domain)
        domain == [] && return domain, []
        append!(new_local_constraints, local_constraints)
    end

    return domain, new_local_constraints
end


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
        if pqitem.size == max_size
            # Check if tree contains holes
            if contains_hole(pqitem.tree)
                # There is no need to expand this tree, since the size limit is reached
                continue
            end
            return (pqitem.tree, pq)
        elseif pqitem.size ≥ max_size
            continue
        end
        expand_result = expand_function(pqitem.tree, grammar, max_depth - 1, GrammarContext(pqitem.tree, [], pqitem.constraints))
        if expand_result ≡ already_complete
            # Current tree is complete, it can be returned
            return (pqitem.tree, pq)
        elseif expand_result ≡ limit_reached
            # The maximum depth is reached
            continue
        elseif expand_result isa Tuple{Vector{AbstractRuleNode}, Vector{LocalConstraint}}
            # Either the current tree can't be expanded due to depth 
            # limit (no expanded trees), or the expansion was successful. 
            # We add the potential expanded trees to the pq and move on to 
            # the next tree in the queue.
            expanded_child_trees, local_constraints = expand_result
            for expanded_tree ∈ expanded_child_trees
                new_pqitem = PQItem(expanded_tree, pqitem.size + 1, local_constraints)
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
The first hole found using a DFS is expanded first.
Returns list of new trees when expansion was succesfull.
Returns nothing if tree is already complete (contains no holes).
Returns empty list if the tree is partial (contains holes), 
    but they couldn't be expanded because of the depth limit.
"""
function _expand(
        node::RuleNode, 
        grammar::ContextSensitiveGrammar, 
        max_depth::Int, 
        context::GrammarContext, 
        expand_heuristic::Function=bfs_expand_heuristic
    )::Union{ExpandFailureReason, Tuple{Vector{AbstractRuleNode}, Vector{LocalConstraint}}}
    # Find any hole. Technically, the type of search doesn't matter.
    # We use recursive DFS for memory efficiency, since depth is limited.
    if grammar.isterminal[node.ind]
        return already_complete
    elseif max_depth ≤ 0
        return limit_reached
    end

    for (child_index, child) ∈ enumerate(node.children)
        child_context = GrammarContext(context.originalExpr, deepcopy(context.nodeLocation), context.constraints)
        push!(child_context.nodeLocation, child_index)
        expand_result = _expand(child, grammar, max_depth - 1, child_context, expand_heuristic)
        if expand_result ≡ already_complete
            # Subtree is already complete
            continue
        elseif expand_result ≡ limit_reached
            # There is a hole that can't be expanded further, so we cannot make this 
            # tree complete anymore. 
            return limit_reached
        elseif expand_result isa Tuple{Vector{AbstractRuleNode}, Vector{LocalConstraint}}
            # Hole was found and expanded
            nodes::Vector{AbstractRuleNode} = []
            expanded_child_trees, local_constraints = expand_result
            for expanded_tree ∈ expanded_child_trees
                # Copy other children of the current node
                children = deepcopy(node.children)
                # Update the child we are expanding
                children[child_index] = expanded_tree
                push!(nodes, RuleNode(node.ind, children))
            end
            return nodes, local_constraints
        else
            error("Got an invalid response of type $(typeof(expand_result)) from `_expand` function")
        end
    end
    # If we searched the entire tree, and we didn't find a hole we could expand, the tree must be complete.
    return already_complete
end

function _expand(
        node::Hole, 
        grammar::ContextSensitiveGrammar, 
        max_depth::Int, 
        context::GrammarContext, 
        expand_heuristic::Function=bfs_expand_heuristic
    )::Union{ExpandFailureReason, Tuple{Vector{AbstractRuleNode}, Vector{LocalConstraint}}}
    if max_depth < 0
        return limit_reached
    end

    nodes::Vector{AbstractRuleNode} = []
    domain, new_constraints::Vector{LocalConstraint} = propagate_constraints(grammar, context, findall(node.domain))
    for rule_index ∈ expand_heuristic(domain)
        push!(nodes, RuleNode(rule_index, grammar))
    end
    return nodes, new_constraints
end

