"""
Count the number of possible expressions of a grammar up to max_depth with start symbol sym.
"""
function count_expressions(grammar::Grammar, max_depth::Int, max_size::Int, sym::Symbol)
    l = 0
    # Calculate length without storing all expressions
    for _ ∈ get_bfs_enumerator(grammar, max_depth, max_size, sym)
        l += 1
    end
    return l
end

"""
Count the number of possible expressions in the expression iterator.
Iterator is not modified.
"""
count_expressions(iter::ExpressionIterator) = count_expressions(iter.grammar, iter.max_depth, iter.max_size, iter.sym)
