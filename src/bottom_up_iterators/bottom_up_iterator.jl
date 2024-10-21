"""
	abstract type BottomUpIterator <: ProgramIterator

Enumerates programs in a bottom-up fashion. This means that complete programs are generated based on a user-provided order (e.g. depth, size, other cost function).
Observational equivalence (i.e. removing programs which yield the same outputs on all examples) is enabled by default.

Concrete implementations of this iterator should design the following custom data structures:
- `bank::BottomUpBank`: Meant to store the list of already-generated programs.
- `data::BottomUpData`: Any additional information the iterator might require.

Additionally, the following functions should be implemented:
- `init_bank(iter::BottomUpIterator)::BottomUpBank`: Returns an initialized `BottomUpBank`.
- `init_data(iter::BottomUpIterator)::BottomUpData`: Returns an initialized `BottomUpData`.
- `create_program!(iter::BottomUpIterator, bank::BottomUpBank, data::BottomUpData)::Union{Nothing, RuleNode}`: Generates the next program. Returns `nothing` if no other programs can be generated.
- `update_state!(iter::BottomUpIterator, bank::BottomUpBank, data::BottomUpData, program::RuleNode)::Nothing`: Called after a program is validated.
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
Additionally, contains `hash_set::Set{UInt64}` used for observational equivalence.
"""
mutable struct BottomUpState
    bank::BottomUpBank
    data::BottomUpData
    hash_set::Set{UInt64}
end

"""
    function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Defines the first iteration of the `BottomUpIterator`. Creates the `BottomUpState` by instantiating its components. Calls `_get_next_program` for generating the next program.
"""
function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    state::BottomUpState = BottomUpState(init_bank(iter), init_data(iter), Set{UInt64}())
    return _get_next_program(iter, state)
end

"""
    function Base.iterate(iter::BottomUpIterator, state::BottomUpState)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Defines the subsequent iterations of the `BottomUpIterator`. Calls `_get_next_program` for generating the next program.
"""
function Base.iterate(
    iter::BottomUpIterator,
    state::BottomUpState
)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    return _get_next_program(iter, state)
end

"""
    function _get_next_program(iter::BottomUpIterator, state::BottomUpState)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Generates and returns the next program. Internally uses the iterator's `create_program!` function to generate programs, which are validated as follows:
1. The program shouldn't exceed the depth limit.
2. The program shouldn't be observationally equivalent to a previous program.
3. The program shouldn't violate any constraints. Note that the `update_state!` function is still called even when the constraints aren't satisfied.
"""
function _get_next_program(
    iter::BottomUpIterator,
    state::BottomUpState
)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    program::Union{Nothing, RuleNode} = create_program!(iter, state.bank, state.data)

    while program !== nothing
        # TODO: optimize this to avoid calling depth for all programs.
        if depth(program) <= get_max_depth(iter.solver) && !_contains_equivalent!(iter, state, program)
            update_state!(iter, state.bank, state.data, program)

            new_state!(iter.solver, program)
            if isfeasible(iter.solver)
                return program, state
            end
        end

        program = create_program!(iter, state.bank, state.data)
    end
    
    return nothing
end

"""
	_contains_equivalent(iter::BottomUpIterator, state::BottomUpState, program::RuleNode)::Bool

Checks whether `program` is observationally equivalent to any previously-iterated program. If it is unique, its hash is pushed to `state.hash_set`.
"""
function _contains_equivalent!(
	iter::BottomUpIterator,
    state::BottomUpState,
    program::RuleNode
)::Bool
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)
    problem = iter.problem

    output = map(example -> execute_on_input(SymbolTable(grammar), rulenode2expr(program, grammar), example.in), problem.spec)
    hashed_output = hash(output)

	if hashed_output ∈ state.hash_set
		return true
	end

    push!(state.hash_set, hashed_output)
	return false
end
