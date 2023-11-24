bfs_priority_function(::Grammar, ::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}) = parent_value + 1


"""
    get_bfs_enumerator(grammar::ContextFreeGrammar, max_depth::Int, max_size::Int, sym::Symbol, hole_heuristic::Function=heuristic_leftmost, derivation_heuristic::Function=(a,_) -> a)::ContextSensitivePriorityEnumerator

Returns a breadth-first search enumerator given a ContextFreeGrammar. Returns trees in the grammar in increasing order of size. 
"""
function get_bfs_enumerator(
    grammar::ContextFreeGrammar, 
    max_depth::Int, 
    max_size::Int, 
    sym::Symbol, 
    hole_heuristic::Function=heuristic_leftmost, 
    derivation_heuristic::Function=(a,_,_) -> a
)::ContextSensitivePriorityEnumerator
    expand_function(node, grammar, max_depth, max_holes, context) = _expand(node, grammar, max_depth, max_holes, context, hole_heuristic, derivation_heuristic)
    return ContextSensitivePriorityEnumerator(cfg2csg(grammar), max_depth, max_size, bfs_priority_function, expand_function, sym)
end

"""
    get_bfs_enumerator(grammar::ContextSensitiveGrammar, max_depth::Int, max_size::Int, sym::Symbol, hole_heuristic::Function=heuristic_leftmost, derivation_heuristic::Function=(a,_) -> a)::ContextSensitivePriorityEnumerator

Returns a breadth-first search enumerator given a ContextSensitiveGrammar. Returns trees in the grammar in increasing order of size. 
"""
function get_bfs_enumerator(
    grammar::ContextSensitiveGrammar, 
    max_depth::Int, 
    max_size::Int, 
    sym::Symbol,
    hole_heuristic::Function=heuristic_leftmost, 
    derivation_heuristic::Function=(a,_,_) -> a
)::ContextSensitivePriorityEnumerator
    expand_function(node, grammar, max_depth, max_holes, context) = _expand(node, grammar, max_depth, max_holes, context, hole_heuristic, derivation_heuristic)
    return ContextSensitivePriorityEnumerator(grammar, max_depth, max_size, bfs_priority_function, expand_function, sym)
end

dfs_priority_function(::Grammar, ::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}) = parent_value - 1


"""
    get_dfs_enumerator(grammar::ContextFreeGrammar, max_depth::Int, max_size::Int, sym::Symbol, hole_heuristic::Function=heuristic_leftmost, derivation_heuristic::Function=(a,_) -> a)::ContextSensitivePriorityEnumerator

Returns a depth-first search enumerator given a ContextFreeGrammar. Returns trees in the grammar in decreasing order of size.
"""
function get_dfs_enumerator(
    grammar::ContextFreeGrammar, 
    max_depth::Int, 
    max_size::Int, 
    sym::Symbol,
    hole_heuristic::Function=heuristic_leftmost, 
    derivation_heuristic::Function=(a,_,_) -> a
)::ContextSensitivePriorityEnumerator
    expand_function(node, grammar, max_depth, max_holes, context) = _expand(node, grammar, max_depth, max_holes, context, hole_heuristic, derivation_heuristic)
    return ContextSensitivePriorityEnumerator(cfg2csg(grammar), max_depth, max_size, dfs_priority_function, expand_function, sym)
end

"""
    get_dfs_enumerator(grammar::ContextSensitiveGrammar, max_depth::Int, max_size::Int, sym::Symbol, hole_heuristic::Function=heuristic_leftmost, derivation_heuristic::Function=(a,_) -> a)::ContextSensitivePriorityEnumerator

Returns a depth-first search enumerator given a ContextSensitiveGrammar. Returns trees in the grammar in decreasing order of size.
"""
function get_dfs_enumerator(
        grammar::ContextSensitiveGrammar, 
        max_depth::Int, 
        max_size::Int, 
        sym::Symbol,
        hole_heuristic::Function=heuristic_leftmost, 
        derivation_heuristic::Function=(a,_,_) -> a    
)::ContextSensitivePriorityEnumerator
    expand_function(node, grammar, max_depth, max_holes, context) = _expand(node, grammar, max_depth, max_holes, context, hole_heuristic, derivation_heuristic)
    return ContextSensitivePriorityEnumerator(grammar, max_depth, max_size, dfs_priority_function, expand_function, sym)
end

"""
    most_likely_priority_function(g::ContextSensitiveGrammar, tree::AbstractRuleNode, ::Union{Real, Tuple{Vararg{Real}}})

Calculates logit for all possible derivations for a node in a tree and returns them.
"""
function most_likely_priority_function(
        g::ContextSensitiveGrammar, 
        tree::AbstractRuleNode, 
        ::Union{Real, Tuple{Vararg{Real}}}
)
    -rulenode_log_probability(tree, g)
end

"""
    get_most_likely_first_enumerator(grammar::ContextFreeGrammar, max_depth::Int, max_size::Int, sym::Symbol, hole_heuristic::Function=heuristic_leftmost, derivation_heuristic::Function=(a,_) -> a)::ContextSensitivePriorityEnumerator

Returns an enumerator that enumerates expressions in the grammar in decreasing order of probability.
Only use this function with probabilistic grammars.
"""
function get_most_likely_first_enumerator(
    grammar::ContextFreeGrammar, 
    max_depth::Int, 
    max_size::Int, 
    sym::Symbol,
    hole_heuristic::Function=heuristic_leftmost, 
    derivation_heuristic::Function=(a,_,_) -> a
)::ContextSensitivePriorityEnumerator
    expand_function(node, grammar, max_depth, max_holes, context) = _expand(node, grammar, max_depth, max_holes, context, hole_heuristic, derivation_heuristic)
    return ContextSensitivePriorityEnumerator(cfg2csg(grammar), max_depth, max_size, most_likely_priority_function, expand_function, sym)
end

"""
    get_most_likely_first_enumerator(grammar::ContextSensitiveGrammar, max_depth::Int, max_size::Int, sym::Symbol, hole_heuristic::Function=heuristic_leftmost, derivation_heuristic::Function=(a,_) -> a)::ContextSensitivePriorityEnumerator

Returns an enumerator that enumerates expressions in the grammar in decreasing order of probability.
Only use this function with probabilistic grammars.
"""
function get_most_likely_first_enumerator(
    grammar::ContextSensitiveGrammar, 
    max_depth::Int, 
    max_size::Int, 
    sym::Symbol,
    hole_heuristic::Function=heuristic_leftmost, 
    derivation_heuristic::Function=(a,_,_) -> a
)::ContextSensitivePriorityEnumerator
    expand_function(node, grammar, max_depth, max_holes, context) = _expand(node, grammar, max_depth, max_holes, context, hole_heuristic, derivation_heuristic)
    return ContextSensitivePriorityEnumerator(grammar, max_depth, max_size, most_likely_priority_function, expand_function, sym)
end
