@programiterator AlternatingRandomGuidedSearchIterator(random_moves_probability=0.3)

Base.IteratorSize(::AlternatingRandomGuidedSearchIterator) = Base.SizeUnknown()
Base.eltype(::AlternatingRandomGuidedSearchIterator) = RuleNode

Base.@kwdef struct AlternatingRandomGuidedSearchState
    guidedsearch_state::Union{HerbSearch.GuidedSearchState,Nothing}
    guidedsearch_iterator::GuidedSearchTraceIterator
end

function Base.iterate(iter::AlternatingRandomGuidedSearchIterator)
    return iterate(iter, AlternatingRandomGuidedSearchState(
        guidedsearch_state=nothing,
        guidedsearch_iterator=GuidedSearchTraceIterator(get_grammar(iter.solver), get_starting_symbol(iter.solver))
    ))
end

function Base.iterate(iter::AlternatingRandomGuidedSearchIterator, state::AlternatingRandomGuidedSearchState)
    if rand() <= iter.random_moves_probability
        return rand(RuleNode, get_grammar(iter.solver), get_starting_symbol(iter.solver)), state
    end
    if isnothing(state.guidedsearch_state)
        program, next_state = iterate(state.guidedsearch_iterator)
    else 
        program, next_state = iterate(state.guidedsearch_iterator, state.guidedsearch_state)
    end
    return program, AlternatingRandomGuidedSearchState(
        guidedsearch_state=next_state,
        guidedsearch_iterator=state.guidedsearch_iterator
    )
end

get_prog_eval(::AlternatingRandomGuidedSearchIterator, prog::Tuple{RuleNode,Tuple{Any,Bool,Number}}) = prog
