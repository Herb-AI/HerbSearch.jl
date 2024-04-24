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

Counts and returns the number of possible expressions in the expression iterator.
!!! warning: modifies and exhausts the iterator
"""
function count_expressions(iter::ProgramIterator)
    l = 0
    # Calculate length without storing all expressions
    for _ ∈ iter
        l += 1
    end
    return l
end


"""
    count_expressions(iter::UniformIterator)    

Counts and returns the number of solutions of a uniform iterator.
!!! warning: modifies and exhausts the iterator
"""
function count_expressions(iter::UniformIterator)
    count = 0
    s = next_solution!(iter)
    while !isnothing(s)
        count += 1
        s = next_solution!(iter)
    end
    return count
end
