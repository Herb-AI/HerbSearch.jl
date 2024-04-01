"""
	mutable struct BottomUpIterator <: ProgramIterator

Enumerates programs in a bottom-up fashion. This means that it starts with the smallest programs and gradually builds up to larger programs.
The exploration of the search space is done in a breadth-first manner, meaning that all programs of a priority are enumerated before moving on to the next ones.

Concrete implementations of this iterator should implement the following methods:
- `order(iter::BottomUpIterator, grammar::ContextSensitiveGrammar)::Vector{Int64}`: Returns the order in which the rules should be enumerated.
- `pick(iter::BottomUpIterator, grammar::ContextSensitiveGrammar, state::BottomUpState, rule::Int64)::Vector{RuleNode}`: Returns the programs that can be created by applying the given rule.
- `priority_function(iter::BottomUpIterator, program::RuleNode, state::BottomUpState)::Int64`: Returns the priority of the given program.
"""
abstract type BottomUpIterator <: ProgramIterator end

# Base.@doc """
# 	@programiterator BasicIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

# A basic implementation of the bottom-up iterator. It will enumerate all programs in a breadth-first manner, starting with the smallest ones.
# Inherits all stop conditions from the BottomUpIterator.
# Needs to have the problem as an argument to be able to hash the outputs of the programs for observing equivalent programs.
# """
@programiterator BasicIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

"""
	mutable struct BottomUpState

Holds the state of the bottom-up iterator. This includes the priority bank, the hashes of the outputs of the programs, and the current programs that are being enumerated.
"""
struct BottomUpState
    priority_bank::Dict{RuleNode,Int64}
    hashes::Set{Int128}
    current_programs::Queue{RuleNode}
end

"""
	order(iter::BottomUpIterator, grammar::ContextSensitiveGrammar)::Vector{Int64}

Returns the order in which the rules should be enumerated.
"""
function order(
    ::BottomUpIterator,
    grammar::ContextSensitiveGrammar
)
    return order(BasicIterator, grammar)
end

"""
	pick(iter::BottomUpIterator, grammar::ContextSensitiveGrammar, state::BottomUpState, rule::Int64)::Vector{RuleNode}

Returns the programs that can be created by applying the given rule.
"""
function pick(
    ::BottomUpIterator,
    grammar::ContextSensitiveGrammar,
    state::BottomUpState,
    rule::Int64
)
    return pick(BasicIterator, grammar, state, rule)
end

"""
	priority_function(iter::BottomUpIterator, program::RuleNode, state::BottomUpState)::Int64

Returns the priority of the given program for the given state.
"""
function priority_function(
    ::BottomUpIterator,
    program::RuleNode,
    state::BottomUpState
)
    return priority_function(BasicIterator, program, state)
end

"""
	order(::BasicIterator, grammar::ContextSensitiveGrammar)

Implements concrete method for the `order` function for the `BasicIterator`.
Function returns all non-terminal rules in the grammar.
"""
function order(
    ::BasicIterator,
    grammar::ContextSensitiveGrammar
)
    return findall(isterminal -> !isterminal, grammar.isterminal)
end

"""
	pick(::BasicIterator, grammar::ContextSensitiveGrammar, state::BottomUpState, rule::Int64)::Vector{RuleNode}

Implements concrete method for the `pick` function for the `BasicIterator`.
Function returns all possible programs that can be created by applying the given rule.
"""
function pick(
    ::BasicIterator,
    grammar::ContextSensitiveGrammar,
    state::BottomUpState,
    rule::Int64
)::Vector{RuleNode}
    new_programs = []
    childtypes = grammar.childtypes[rule]

    permuatations = Combinatorics.permutations(collect(keys(state.priority_bank)), length(childtypes))

    for rulenode_permutation ∈ permuatations
        if map(rulenode -> grammar.types[rulenode.ind], rulenode_permutation) == childtypes
            new_single_program = RuleNode(rule, nothing, rulenode_permutation)

            push!(new_programs, new_single_program)
        end
    end

    return new_programs
end

"""
	priority_function(::BasicIterator, program::RuleNode, state::BottomUpState)::Int64

Implements concrete method for the `priority_function` function for the `BasicIterator`.
Function returns the maximum priority - based on the size of the program - of the children of the given program plus one.
"""
function priority_function(
    ::BasicIterator,
    program::RuleNode,
    state::BottomUpState
)::Int64
    retval::Int64 = 0

    for child ∈ program.children
        retval = max(retval, state.priority_bank[child])
    end

    return retval + 1
end


"""
	Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Describes the iteration process of the bottom-up iterator. It starts with the smallest programs and gradually builds up to larger programs. 
Also, fills the state with the first, terminal programs and their priorities, which are initialized to 1. The function returns the first program and the state of the iterator.
"""
function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    current_programs = Queue{RuleNode}()
    bank::Base.Dict{RuleNode,Int64} = Dict()
	hashes::Set{Int128} = Set{Int128}()

    for terminal in findall(iter.grammar.isterminal)
        current_single_program::RuleNode = RuleNode(terminal, nothing, [])

        enqueue!(current_programs, current_single_program)
        bank[current_single_program] = 1
    end

    state::BottomUpState = BottomUpState(bank, hashes, current_programs)
    return _get_next_program(iter, state)
end

"""
	Base.iterate(iter::BottomUpIterator, state::BottomUpState)

Describes the iteration process of the bottom-up iterator. It starts with the smallest programs and gradually builds up to larger programs.
The function returns the next program and changes the state of the iterator.
"""
function Base.iterate(iter::BottomUpIterator, state::BottomUpState)
    next_program = _get_next_program(iter, state)
    if next_program ≠ nothing
        return next_program
    end

    rules::Vector{Int64} = order(iter, iter.grammar)
    for rule in rules
        new_programs = pick(iter, iter.grammar, state, rule)
        for new_program ∈ new_programs

            enqueue!(state.current_programs, new_program)
        end
    end

    return _get_next_program(iter, state)
end

"""
	_get_next_program(iter::BottomUpIterator, state::BottomUpState)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Returns the next program and changes the state of the iterator. Checks if the program is equivalent to the ones that have already been enumerated.
Places the program in the priority bank and hashed output bank.
"""
function _get_next_program(
    iter::BottomUpIterator,
    state::BottomUpState
)::Union{Nothing,Tuple{RuleNode, BottomUpState}}


    while !isempty(state.current_programs) && _contains_equivalent(iter, state, first(state.current_programs))
        dequeue!(state.current_programs)
    end

    if isempty(state.current_programs)
        return nothing
    end

    new_program::RuleNode = dequeue!(state.current_programs)
    state.priority_bank[new_program] = priority_function(iter, new_program, state)
    return new_program, state
end

"""
	_contains_equivalent(iter::BottomUpIterator, state::BottomUpState, program::RuleNode)::Bool

Checks if the program is equivalent to the ones that have already been enumerated.
"""
function _contains_equivalent(
	iter::BottomUpIterator,
	state::BottomUpState,
	program::RuleNode
)::Bool
	hashed_output = _hash_outputs_for_program(iter, program, iter.problem)

	if hashed_output ∈ state.hashes
		return true
	end

	push!(state.hashes, hashed_output)
	return false
end

"""
	_hash_outputs_for_program(iter::BottomUpIterator, new_program::RuleNode, problem::Problem{Vector{IOExample}})::UInt

Hashes the outputs of the programs for observing equivalent programs. Usese the XOR operator to combine the hashes of the outputs.
"""	
function _hash_outputs_for_program(
	iter::BottomUpIterator,
	new_program::RuleNode,
    problem::Problem{Vector{IOExample}}
)::UInt
    retval::UInt = 0

    for example ∈ problem.spec
        output = execute_on_input(SymbolTable(iter.grammar), rulenode2expr(new_program, iter.grammar), example.in)
        retval = hash(retval ⊻ hash(output))
    end

    return retval
end
