Base.@doc """
    @programiterator BUDepthIterator(problem::Union{Nothing, Problem{Vector{IOExample}}}=nothing, obs_equivalence::Bool=false) <: BottomUpIterator

Implementation of the `BottomUpIterator`. Iterates through complete programs in increasing order of their depth.
""" BUDepthIterator
@programiterator BUDepthIterator() <: BottomUpIterator

const Depth = UInt32

"""
    struct BUDepthBank <: BottomUpBank
"""
struct BUDepthBank <: BottomUpBank
    depth_symbol_program_map::Dict{Depth, Dict{Symbol, RuleNode}}
end

BottomUpBank(iter::BUDepthIterator) = BUDepthBank(iter)

"""
	BUDepthBank(iter::BUDepthIterator)::BUDepthBank
"""
function BUDepthBank(
    iter::BUDepthIterator
)::BUDepthBank
    # grammar::ContextSensitiveGrammar = get_grammar(iter.solver)
    # depth_symbol_program_map = Dict{Depth, Dict{Symbol, RuleNode}}()

    # for symbol ∈ grammar.types
    #     rulenodes_by_symbol[symbol] = Vector{RuleNode}()
    # end

    # return BUDepthBank(rulenodes_by_symbol)
end

"""
    struct BUDepthData <: BottomUpData

TODO: Explain each field of this class.
"""
mutable struct BUDepthData <: BottomUpData
end

BottomUpData(iter::BUDepthIterator) = BUDepthData(iter)

"""
    BUDepthData(iter::BUDepthIterator)::BUDepthData
"""
function BUDepthData(
    iter::BUDepthIterator
)::BUDepthData
    # grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

    # empty_nested_iterator::NestedRulenodeIterator = NestedRulenodeIterator()
    # depth::Int = 1

    # rules::Queue{Int} = Queue{Int}()
    # for (rule_index, is_terminal) ∈ enumerate(grammar.isterminal)
    #     if is_terminal
    #         enqueue!(rules, rule_index)
    #     end
    # end

    # return BUDepthData(empty_nested_iterator, Vector{RuleNode}(), rules, depth)
end

function combine!(
    iter::BUDepthIterator,
    data::BUDepthData,
    bank::BUDepthBank
)::RuleNodeCombinations
    # TODO
end

function is_valid(
    iter::BUDepthIterator,
    program::RuleNode,
    data::BUDepthData
)::Bool
    # TODO
end

function add_to_bank!(
    iter::BUDepthIterator,
    bank::BUDepthBank,
    program::RuleNode
)::Nothing
    # TODO
end