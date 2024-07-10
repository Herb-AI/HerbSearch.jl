@programiterator BadIterator()

Base.@kwdef struct BadIteratorState
    current_program::RuleNode
end

Base.IteratorSize(::BadIterator) = Base.SizeUnknown()
Base.eltype(::BadIterator) = RuleNode


function Base.iterate(iter::BadIterator)
    sampled_program = rand(RuleNode, get_grammar(iter.solver))
    return (sampled_program, BadIteratorState(sampled_program))
end


function Base.iterate(iter::BadIterator, current_state::BadIteratorState)
    return (current_state.current_program, current_state)
end
