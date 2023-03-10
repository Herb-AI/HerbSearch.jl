"""
Enumerates a context-free grammar up to a given depth in a breadth-first order.
This means that smaller programs are returned before larger programs.
"""
mutable struct ContextSensitivePriorityEnumerator <: ExpressionIterator 
    grammar::ContextSensitiveGrammar
    max_depth::Int
    # Assigns a priority to a (partial or complete) tree.
    priority_function::Function
    # Expands a partial tree.
    expand_function::Function
    sym::Symbol
end 


function Base.iterate(iter::ContextSensitivePriorityEnumerator)
    # Priority queue with number of nodes in the program
    pq :: PriorityQueue{RuleNode, Union{Real, Tuple{Vararg{Real}}}} = PriorityQueue()

    grammar, max_depth, sym = iter.grammar, iter.max_depth, iter.sym
    priority_function, expand_function = iter.priority_function, iter.expand_function

    init_node = RuleNode(0)
    init_context = GrammarContext(init_node)

    rules = [x for x ∈ grammar[sym]]
    rules = propagate_constraints(grammar, init_context, rules)

    for r ∈ rules
        node = RuleNode(r)
        enqueue!(pq, node, priority_function(grammar, node, 0))
    end
    return _find_next_complete_tree(grammar, max_depth, priority_function, expand_function, pq)
end


function Base.iterate(iter::ContextSensitivePriorityEnumerator, pq::DataStructures.PriorityQueue)
    grammar, max_depth = iter.grammar, iter.max_depth
    priority_function, expand_function = iter.priority_function, iter.expand_function
    return _find_next_complete_tree(grammar, max_depth, priority_function, expand_function, pq)
end


"""
Takes a priority queue and returns the smallest AST from the grammar it can obtain from the
queue or by (repeatedly) expanding trees that are in the queue.
Returns nothing if there are no trees left within the depth limit.
"""
function _find_next_complete_tree(grammar::ContextSensitiveGrammar, max_depth::Int, priority_function::Function, expand_function::Function, pq::PriorityQueue)
    while length(pq) ≠ 0
        (tree, priority_value) = dequeue_pair!(pq)
        expanded_trees = expand_function(tree, grammar, max_depth - 1, GrammarContext(tree))
        if expanded_trees ≡ nothing
            # Current tree is complete, it can be returned
            return (tree, pq)
        else
            # Either the current tree can't be expanded due to depth 
            # limit (no expanded trees), or the expansion was successful. 
            # We add the potential expanded trees to the pq and move on to 
            # the next tree in the queue.
            for expanded_tree ∈ expanded_trees
                # Pass the local scope to the function for calculating the priority 
                enqueue!(pq, expanded_tree, priority_function(grammar, expanded_tree, priority_value))
            end
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
function _expand(node::RuleNode, grammar::ContextSensitiveGrammar, max_depth::Int, context::GrammarContext, expand_heuristic::Function=bfs_expand_heuristic)
    # Find any hole. Technically, the type of search doesn't matter.
    # We use recursive DFS for memory efficiency, since depth is limited.
    if grammar.isterminal[node.ind]
        return nothing
    elseif max_depth ≤ 0
        return []
    end

    childtypes = grammar.childtypes[node.ind]
    # This node doesn't have holes, check the children
    if length(childtypes) == length(node.children)
        for (child_index, child) ∈ enumerate(node.children)
            child_context = GrammarContext(context.originalExpr, deepcopy(context.nodeLocation))
            push!(child_context.nodeLocation, child_index)
            expanded_child_trees = _expand(child, grammar, max_depth - 1, child_context, expand_heuristic)
            if expanded_child_trees ≡ nothing
                # Subtree is already complete
                continue
            elseif expanded_child_trees == []
                # There is a hole that can't be expanded further, so we cannot make this 
                # tree complete anymore. 
                return []
            else
                # Hole was found and expanded
                nodes = []
                for expanded_tree ∈ expanded_child_trees
                    # Copy other children of the current node
                    children = deepcopy(node.children)
                    # Update the child we are expanding
                    children[child_index] = expanded_tree
                    push!(nodes, RuleNode(node.ind, children))
                end
                return nodes
            end

        end
    else # This node has an unfilled hole
        child_type = childtypes[length(node.children) + 1]
        nodes = []

        for rule_index ∈ expand_heuristic(propagate_constraints(grammar, context, deepcopy(grammar[child_type])))
            # Copy existing children of the current node
            children = deepcopy(node.children)
            # Add the child we are expanding
            push!(children, RuleNode(rule_index))
            push!(nodes, RuleNode(node.ind, children))
        end
        return nodes
    end
end

