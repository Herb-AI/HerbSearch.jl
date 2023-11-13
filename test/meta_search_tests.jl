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


@testset "MetaRunner runs" begin
    Mocking.activate()  # Need to call `activate` before executing `apply`

    # mh() = get_mh_enumerator(examples, HerbSearch.mean_squared_error)
    # sa(inital_temperature, temperature_decreasing_factor) = get_sa_enumerator(examples, HerbSearch.mean_squared_error, inital_temperature, temperature_decreasing_factor)
    # vlsn(enumeration_depth) = get_vlsn_enumerator(examples, HerbSearch.mean_squared_error, enumeration_depth)


    patch1 = @patch sa(inital_temperature, temperature_decreasing_factor) = get_bad_iterator()
    patch2 = @patch vlsn(enumeration_depth) = get_bad_iterator()
    # apply(patch1) do 
    #     apply(patch2) do 
    #         run_meta_search()            
    #     end
    # end
    # run_meta_search()
end