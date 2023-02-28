bfs_priority_function(tree::RuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}) = parent_value + 1
bfs_expand_heuristic(rules) = rules


"""
Returns a breadth-first search enumerator. Returns trees in the grammar in increasing order of size. 
"""
function get_bfs_enumerator(grammar::ContextFreeGrammar, max_depth::Int, sym::Symbol)::ContextFreePriorityEnumerator
    expand_function(node, grammar, max_depth) = _expand(node, grammar, max_depth, bfs_expand_heuristic)
    return ContextFreePriorityEnumerator(grammar, max_depth, bfs_priority_function, expand_function, sym)
end

function get_bfs_enumerator(grammar::ContextSensitiveGrammar, max_depth::Int, sym::Symbol)::ContextSensitivePriorityEnumerator
    expand_function(node, grammar, max_depth, context) = _expand(node, grammar, max_depth, context, bfs_expand_heuristic)
    return ContextSensitivePriorityEnumerator(grammar, max_depth, bfs_priority_function, expand_function, sym)
end

dfs_priority_function(tree::RuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}) = parent_value - 1
dfs_expand_heuristic(rules) = rules


"""
Returns a depth-first search enumerator. Returns trees in the grammar in decreasing order of size.
"""
function get_dfs_enumerator(grammar::ContextFreeGrammar, max_depth::Int, sym::Symbol)::ContextFreePriorityEnumerator
    expand_function(node, grammar, max_depth) = _expand(node, grammar, max_depth, dfs_expand_heuristic)
    return ContextFreePriorityEnumerator(grammar, max_depth, dfs_priority_function, expand_function, sym)
end

function get_dfs_enumerator(grammar::ContextSensitiveGrammar, max_depth::Int, sym::Symbol)::ContextSensitivePriorityEnumerator
    expand_function(node, grammar, max_depth, context) = _expand(node, grammar, max_depth, context, dfs_expand_heuristic)
    return ContextSensitivePriorityEnumerator(grammar, max_depth, dfs_priority_function, expand_function, sym)
end