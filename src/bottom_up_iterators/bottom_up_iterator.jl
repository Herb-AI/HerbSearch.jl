"""
	abstract type BottomUpIterator <: ProgramIterator

Enumerates programs in a bottom-up fashion. This means that complete programs are generated based on a user-provided order (e.g. depth, size, other cost function).

Concrete implementations of this iterator should design the following custom data structures:
- `bank::BottomUpBank`: Store the list of already-generated programs (i.e. program bank).
- `data::BottomUpData`: Store any additional information the iterator might require.

The following functions should be implemented:
- `BottomUpBank(iter::BottomUpIterator)::BottomUpBank`: Returns an initialized `BottomUpBank`.
- `BottomUpData(iter::BottomUpIterator)::BottomUpData`: Returns an initialized `BottomUpData`.
- `combine!(iter::BottomUpIterator, bank::BottomUpBank, data::BottomUpData)::RuleNodeCombinations`: TODO
- `is_valid(iter::BottomUpIterator, program::RuleNode, data::BottomUpData)::Bool`: TODO
- `add_to_bank!(iter::BottomUpIterator, bank::BottomUpBank, program::RuleNode)::Nothing`: TODO
"""
abstract type BottomUpIterator{T <: AbstractRuleNode} <: ProgramIterator end

"""
    abstract type BottomUpBank

Concrete iterator implementations should define a custom type extending `BottomUpBank` for storing their `bank` data structure.
"""
abstract type BottomUpBank{T <: AbstractRuleNode} end

"""
    abstract type BottomUpData

Concrete iterator implementations should define a custom type extending `BottomUpData` for storing their `data` data structure.
"""
abstract type BottomUpData{T <: AbstractRuleNode} end

"""
    mutable struct BottomUpIteratorTuple

TODO: add documentation
"""
mutable struct BottomUpIteratorTuple
    cross_product_iterator::CrossProductIterator
    abstract_rulenode_iterator::AbstractRuleNodeIterator
end

function BottomUpIteratorTuple(
    iter::BottomUpIterator{T},
    rulenode_combinations::RuleNodeCombinations,
    bank::BottomUpBank{T},
    data::BottomUpData{T}
)::Union{Nothing, BottomUpIteratorTuple} where T
    grammar = get_grammar(iter.solver)
    cross_product_iterator = CrossProductIterator(rulenode_combinations)
    program_collection = _get_next_program_collection!(iter, cross_product_iterator, bank, data)
    if isnothing(program_collection)
        return nothing
    end

    abstract_rulenode_iterator = create_abstract_rulenode_iterator(program_collection, grammar)
    return BottomUpIteratorTuple(cross_product_iterator, abstract_rulenode_iterator)
end

function _get_next_program_collection!(
    iter::BottomUpIterator{T},
    cross_product_iterator::CrossProductIterator,
    bank::BottomUpBank{T},
    data::BottomUpData{T}
)::Union{Nothing, AbstractRuleNode} where T
    program_collection = iterate(cross_product_iterator)

    # Skip over the program collections that won't be added to the bank.
    # (i.e. invalid program collections)
    while !isnothing(program_collection)
        if is_valid(iter, program_collection, data)
            add_to_bank!(iter, bank, program_collection)
            return program_collection
        else
            program_collection = iterate(cross_product_iterator)
        end
    end

    return nothing
end

"""
    mutable struct BottomUpState

Structure defining the internal state of the iterator. Contains the user-defined `bank::BottomUpBank` and `data::BottomUpData`.
Additionally, it contains interface-handled data structures (`cross_product_iterator::CrossProductIterator`).
"""
mutable struct BottomUpState{T <: AbstractRuleNode}
    # User defined.
    bank::BottomUpBank{T}
    data::BottomUpData{T}

    # Handled by the generic implementation.
    iterator_tuple::Union{Nothing, BottomUpIteratorTuple}
end

"""
    function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Defines the first iteration of the `BottomUpIterator`.
"""
function Base.iterate(
    iter::BottomUpIterator{T}
)::Union{Nothing,Tuple{RuleNode,BottomUpState{T}}} where T
    bank::BottomUpBank{T} = BottomUpBank{T}(iter)
    data::BottomUpData{T} = BottomUpData{T}(iter)

    state::BottomUpState{T} = BottomUpState{T}(bank, data, nothing)
    return _get_next_program(iter, state)
end

"""
    function Base.iterate(iter::BottomUpIterator, state::BottomUpState)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Defines the subsequent iterations of the `BottomUpIterator`.
"""
function Base.iterate(
    iter::BottomUpIterator{T},
    state::BottomUpState{T}
)::Union{Nothing,Tuple{RuleNode,BottomUpState}} where T
    return _get_next_program(iter, state)
end

"""
    function _get_next_program(iter::BottomUpIterator, state::BottomUpState)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

TODO: add documentation
"""
function _get_next_program(
    iter::BottomUpIterator{T},
    state::BottomUpState{T}
)::Union{Nothing,Tuple{RuleNode,BottomUpState}} where T
    while true
        if isnothing(state.iterator_tuple)
            rulenode_combinations = combine!(iter, state.bank, state.data)
            if isnothing(rulenode_combinations)
                return nothing
            end
            state.iterator_tuple = BottomUpIteratorTuple(iter, rulenode_combinations, state.bank, state.data)
        else 
            next_program = iterate(state.iterator_tuple.abstract_rulenode_iterator)
            if isnothing(next_program)
                program_collection = _get_next_program_collection!(iter, state.iterator_tuple.cross_product_iterator, state.bank, state.data)
                if isnothing(program_collection)
                    state.iterator_tuple = nothing
                else
                    grammar = get_grammar(iter.solver)
                    state.iterator_tuple.abstract_rulenode_iterator = create_abstract_rulenode_iterator(program_collection, grammar)
                end
            else
                return next_program, state
            end
        end
    end
end