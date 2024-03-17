struct BadIterator <: ExpressionIterator
    grammar::ContextSensitiveGrammar
end

Base.@kwdef struct BadIteratorState
    current_program::RuleNode
end

import HerbSearch.construct_state_from_start_program

function HerbSearch.construct_state_from_start_program(::Type{BadIterator}; start_program::RuleNode) 
    return BadIteratorState(current_program = start_program)
end

Base.IteratorSize(::BadIterator) = Base.SizeUnknown()
Base.eltype(::BadIterator) = RuleNode


function Base.iterate(iter::BadIterator)
    Random.seed(1)
    sampled_program = rand(RuleNode, iter.grammar)
    return (sampled_program, BadIteratorState(sampled_program))
end


"""
    Base.iterate(iter::BadIterator, current_state::BadIteratorState)
"""
function Base.iterate(iter::BadIterator, current_state::BadIteratorState)
    return (current_state.current_program, current_state)
end

function get_bad_iterator()
    return (grammar, _, _, _) -> begin
        return BadIterator(grammar)
    end
end
