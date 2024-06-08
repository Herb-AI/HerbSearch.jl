@programiterator MyRandomSearchIterator()

Base.IteratorSize(::MyRandomSearchIterator) = Base.SizeUnknown()
Base.eltype(::MyRandomSearchIterator) = RuleNode

function Base.iterate(iter::MyRandomSearchIterator)
    return rand(RuleNode, get_grammar(iter.solver), get_starting_symbol(iter.solver)), nothing
end

function Base.iterate(iter::MyRandomSearchIterator, _)
    return iterate(iter)
end
