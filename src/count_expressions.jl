"""
    count_expressions(grammar::AbstractGrammar, max_depth::Int, max_size::Int, sym::Symbol)

Counts and returns the number of possible expressions of a grammar up to max_depth with start symbol sym.
"""
function count_expressions(grammar::AbstractGrammar, max_depth::Int, max_size::Int, sym::Symbol)
    l = 0
    # Calculate length without storing all expressions
    for _ ∈ BFSIterator(grammar, sym, max_depth=max_depth, max_size=max_size)
        l += 1
    end
    return l
end

"""
    count_expressions(iter::ProgramIterator)    

Counts and returns the number of possible expressions in the expression iterator. The Iterator is not modified.
"""
count_expressions(iter::ProgramIterator) = count_expressions(get_grammar(iter.solver), iter.max_depth, iter.max_size, iter.sym)
