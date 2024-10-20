"""
	abstract type BottomUpIterator <: ProgramIterator

Enumerates programs in a bottom-up fashion. This means that it starts with the smallest programs and gradually builds up to larger programs.
The exploration of the search space is done by making use of the priority function, which associates each program with its cost.

Concrete implementations of this iterator should implement the following methods:
- `order(iter::BottomUpIterator, grammar::ContextSensitiveGrammar)::Vector{Int64}`: Returns the order in which the rules should be enumerated.
- `pick(iter::BottomUpIterator, grammar::ContextSensitiveGrammar, state::BottomUpState, rule::Int64)::Vector{RuleNode}`: Returns the programs that can be created by applying the given rule.
- `priority_function(iter::BottomUpIterator, grammar::ContextSensitiveGrammar, program::RuleNode, state::BottomUpState)::Int64`: Returns the priority of the given program.
"""
abstract type BottomUpIterator <: ProgramIterator end

abstract type BottomUpBank end

abstract type BottomUpData end

mutable struct BottomUpState
    bank::BottomUpBank
    data::BottomUpData
    hash_set::Set{UInt64}
end

function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    state::BottomUpState = BottomUpState(init_bank(iter), init_data(iter), Set{UInt64}())
    return _get_next_program(iter, state)
end

function Base.iterate(
    iter::BottomUpIterator,
    state::BottomUpState
)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    return _get_next_program(iter, state)
end

function _get_next_program(
    iter::BottomUpIterator,
    state::BottomUpState
)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    program::Union{Nothing, RuleNode} = create_program(iter, state.bank, state.data)

    while program !== nothing
        # TODO: optimize this to avoid calling depth for all programs
        if depth(program) <= get_max_depth(iter.solver) && !_contains_equivalent!(iter, state, program)
            update_state!(iter, state.bank, state.data, program)

            new_state!(iter.solver, program)
            if isfeasible(iter.solver)
                return program, state
            end
        end

        program = create_program(iter, state.bank, state.data)
    end
    
    return nothing
end

"""
	_contains_equivalent(iter::BottomUpIterator, state::BottomUpState, program::RuleNode)::Bool

Checks if the program is equivalent to the ones that have already been enumerated. If it is unique, its hashed is pushed to hash_set
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
