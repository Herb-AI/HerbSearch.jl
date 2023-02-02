"""
Enumerates a context-free grammar up to a given depth in a breadth-first order.
This means that smaller programs are returned before larger programs.
"""
mutable struct ContextFreeBFSEnumerator <: ExpressionIterator 
    grammar::ContextFreeGrammar
    max_depth::Int
    sym::Symbol
end


function Base.iterate(iter::ContextFreeBFSEnumerator)
    # Priority queue with number of nodes in the program
    pq :: PriorityQueue{RuleNode, Int} = PriorityQueue()

    grammar, max_depth, sym = iter.grammar, iter.max_depth, iter.sym
    for r ∈ grammar[sym]
        enqueue!(pq, RuleNode(r), 1)
    end
    return _find_next_complete_tree(grammar, max_depth, pq)
end


function Base.iterate(iter::ContextFreeBFSEnumerator, pq::DataStructures.PriorityQueue)
    grammar, max_depth, _ = iter.grammar, iter.max_depth, iter.sym
    return _find_next_complete_tree(grammar, max_depth, pq)
end


"""
Takes a priority queue and returns the smallest AST from the grammar it can obtain from the
queue or by (repeatedly) expanding trees that are in the queue.
Returns nothing if there are no trees left within the depth limit.
"""
function _find_next_complete_tree(grammar::ContextFreeGrammar, max_depth::Int, pq::PriorityQueue)
    while length(pq) ≠ 0
        (tree, size) = dequeue_pair!(pq)
        expanded_trees = _expand(tree, grammar, max_depth - 1)
        if expanded_trees ≡ nothing
            # Current tree is complete, it can be returned
            return (tree, pq)
        else
            # Either the current tree can't be expanded due to depth 
            # limit (no expanded trees), or the expansion was successful. 
            # We add the potential expanded trees to the pq and move on to 
            # the next tree in the queue.
            for expanded_tree ∈ expanded_trees
                enqueue!(pq, expanded_tree, size + 1)
            end
        end
    end
    return nothing
end


"""
Expands one hole/undefined leaf of the given RuleNode tree.
Returns list of new trees when expansion was succesfull.
Returns nothing if tree is already complete (contains no holes).
Returns empty list if the tree is partial (contains holes), 
    but they couldn't be expanded because of the depth limit.
"""
function _expand(node::RuleNode, grammar::ContextFreeGrammar, max_depth::Int)
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
            expanded_child_trees = _expand(child, grammar, max_depth - 1)
            if expanded_child_trees ≡ nothing
                # Subtree is already complete
                continue
            elseif expanded_child_trees == []
                # There is a hole can't be expanded further, so we cannot make this 
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
        for rule_index ∈ grammar[child_type]
            # Copy existing children of the current node
            children = deepcopy(node.children)
            # Add the child we are expanding
            push!(children, RuleNode(rule_index))
            push!(nodes, RuleNode(node.ind, children))
        end
        return nodes
    end
end

