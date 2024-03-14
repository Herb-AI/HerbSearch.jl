using HerbSearch
using Test
using Mocking

#TODO Tests: Write proper meta-search tests.
Base.@kwdef mutable struct BadIterator <: ExpressionIterator
    grammar::ContextSensitiveGrammar
end

Base.@kwdef struct BadIteratorState
    current_program::RuleNode
end

Base.IteratorSize(::BadIterator) = Base.SizeUnknown()
Base.eltype(::BadIterator) = RuleNode


function Base.iterate(iter::BadIterator)
    grammar, max_depth = iter.grammar, iter.max_depth
    dmap = mindepth_map(grammar)
    sampled_program = rand(RuleNode, grammar, iter.start_symbol, max_depth)
    return (sampled_program, BadIteratorState(sampled_program,dmap))
end


"""
    Base.iterate(iter::StochasticSearchEnumerator, current_state::StochasticIteratorState)

"""
function Base.iterate(iter::BadIterator, current_state::BadIteratorState)
    return (current_state.current_program, current_state)
end

function get_bad_iterator(grammar)
    return BadIterator(grammar)
end
