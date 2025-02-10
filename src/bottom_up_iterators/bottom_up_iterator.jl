"""
	abstract type BottomUpIterator <: ProgramIterator

Enumerates programs in a bottom-up fashion. This means that complete programs are generated based on a user-provided order (e.g. depth, size, other cost function).

Concrete implementations of this iterator should design the following custom data structures:
- `bank::BottomUpBank`: Meant to store the list of already-generated programs.
- `data::BottomUpData`: Any additional information the iterator might require.

Additionally, the following functions should be implemented:
- `init_bank(iter::BottomUpIterator)::BottomUpBank`: Returns an initialized `BottomUpBank`.
- `init_data(iter::BottomUpIterator)::BottomUpData`: Returns an initialized `BottomUpData`.
- `create_program!(iter::BottomUpIterator, bank::BottomUpBank, data::BottomUpData)::Union{Nothing, RuleNode}`: Generates the next program. Returns `nothing` if no other programs can be generated.
- `update_state!(iter::BottomUpIterator, bank::BottomUpBank, data::BottomUpData, program::RuleNode)::Nothing`: Called after a program is validated.

Observational equivalence (i.e. removing programs which yield the same outputs on all examples) is an optional optimization which could be used by `BottomUpIterator`s.
To enable it, add the following fields to the `BottomUpIterator` implementation:
- `problem::Union{Nothing, Problem{Vector{IOExample}}}.
- `obs_equivalence::Bool` (and set this to `true` when creating the `BottomUpIterator`).
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
Additionally, contains `enable_observational_equivalence::Bool`, which specifies if the observational equivalence optimization is enabled and `observational_equivalence_hashes::Set{UInt64}` used for storing the hashes of the generated programs.
"""
mutable struct BottomUpState
    bank::BottomUpBank
    data::BottomUpData
    enable_observational_equivalence::Bool
    observational_equivalence_hashes::Set{UInt64}
end

"""
    function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Defines the first iteration of the `BottomUpIterator`. Creates the `BottomUpState` by instantiating its components. Calls `_get_next_program` for generating the next program.
"""
function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    state::BottomUpState = BottomUpState(init_bank(iter), init_data(iter), _has_obs_equivalence(iter), Set{UInt64}())
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
    _has_obs_equivalence(iter::BottomUpIterator)::Bool

Returns `true` if the observational equivalence is enabled in the provided `BottomUpIterator` and `false` otherwise.
"""
function _has_obs_equivalence(iter::BottomUpIterator)::Bool
    fields = fieldnames(typeof(iter))
    has_obs_equivalence_field = :obs_equivalence ∈ fields
    has_problem_field = :problem ∈ fields

    if !has_obs_equivalence_field
        return false
    end

    @assert has_problem_field "A BottomUpIterator containing the 'obs_equivalence' field must have a 'problem' field."
    @assert !iter.obs_equivalence || !isnothing(iter.problem) "If `obs_equivalence` is set to true, a 'Problem' instance should be provided."

    return iter.obs_equivalence
end

"""
    function _get_next_program(iter::BottomUpIterator, state::BottomUpState)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Generates and returns the next program. Internally uses the iterator's `create_program!` function to generate programs, which are validated as follows:
1. The program shouldn't exceed the depth limit.
2. If observational equivalence is enabled, ensures the program isn't observationally equivalent to a previous program.
3. The program shouldn't violate any constraints. Note that the `update_state!` function is still called even when the constraints aren't satisfied.
"""
function _get_next_program(
    iter::BottomUpIterator,
    state::BottomUpState
)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    program::Union{Nothing, RuleNode} = create_program!(iter, state.bank, state.data)

    while program !== nothing
        if depth(program) <= get_max_depth(iter.solver)
            # Check if an observationally equivalent program was found.
            if !state.enable_observational_equivalence || !_contains_equivalent!(iter, state, program)
                update_state!(iter, state.bank, state.data, program)
    
                new_state!(iter.solver, program)
                if isfeasible(iter.solver)
                    return program, state
                end
            end
        end
        program = create_program!(iter, state.bank, state.data)
    end
    
    return nothing
end

"""
	_contains_equivalent(iter::BottomUpIterator, state::BottomUpState, program::RuleNode)::Bool

Checks whether `program` is observationally equivalent to any previously-iterated program. If it isn't, its hash is pushed to `state.observational_equivalence_hashes`.
"""
function _contains_equivalent!(
	iter::BottomUpIterator,
    state::BottomUpState,
    program::RuleNode
)::Bool
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)
    problem = iter.problem

    try
        output = map(example -> execute_on_input(grammar, program, example.in), problem.spec)
        hashed_output = hash(output)

        if hashed_output ∈ state.observational_equivalence_hashes
            return true
        end

        push!(state.observational_equivalence_hashes, hashed_output)
        return false
    catch
        # If any exception results from running the program, we ignore it.
        return true
    end
end
