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
abstract type BottomUpIterator <: ProgramIterator end

"""
    abstract type BottomUpBank

Concrete iterator implementations should define a custom type extending `BottomUpBank` for storing their `bank` data structure.
"""
abstract type BottomUpBank end

"""
    abstract type BottomUpData

Concrete iterator implementations should define a custom type extending `BottomUpData` for storing their `data` data structure.
"""
abstract type BottomUpData end

"""
    mutable struct BottomUpState

Structure defining the internal state of the iterator. Contains the user-defined `bank::BottomUpBank` and `data::BottomUpData`.
Additionally, it contains interface-handled data structures (`cross_product_iterator::CrossProductIterator`).
"""
mutable struct BottomUpState
    # User defined.
    bank::BottomUpBank
    data::BottomUpData

    # Handled by the generic implementation.
    cross_product_iterator::CrossProductIterator
end

"""
    function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Defines the first iteration of the `BottomUpIterator`.
"""
function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    state::BottomUpState = BottomUpState(BottomUpBank(iter), BottomUpData(iter), CrossProductIterator(RuleNodeCombinations(0, Vector{Vector{RuleNode}}())))
    state.cross_product_iterator = CrossProductIterator(combine!(iter, state.data, state.bank))
    println("cross prodtuct ", state.cross_product_iterator)
    return _get_next_program(iter, state)
end

"""
    function Base.iterate(iter::BottomUpIterator, state::BottomUpState)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Defines the subsequent iterations of the `BottomUpIterator`.
"""
function Base.iterate(
    iter::BottomUpIterator,
    state::BottomUpState
)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    return _get_next_program(iter, state)
end

"""
    function _get_next_program(iter::BottomUpIterator, state::BottomUpState)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

TODO: add documentation
"""
function _get_next_program(
    iter::BottomUpIterator,
    state::BottomUpState
)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    while true
        next_program = Base.iterate(state.cross_product_iterator)

        if isnothing(next_program)
            rulenode_combinations = combine!(iter, state.bank, state.data)
            if isnothing(rulenode_combinations)
                return nothing
            end

            state.cross_product_iterator = CrossProductIterator(rulenode_combinations)
            continue
        end

        if is_valid(iter, next_program, state.data)
            add_to_bank(iter, state.bank, next_program)
            return next_program, state
        end
    end
end