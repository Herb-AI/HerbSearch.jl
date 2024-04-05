"""
	mutable struct BottomUpIterator <: ProgramIterator

Enumerates programs in a bottom-up fashion. This means that it starts with the smallest programs and gradually builds up to larger programs.
The exploration of the search space is done by making use of the priority function, which associates each program with its cost.

Concrete implementations of this iterator should implement the following methods:
- `order(iter::BottomUpIterator, grammar::ContextSensitiveGrammar)::Vector{Int64}`: Returns the order in which the rules should be enumerated.
- `pick(iter::BottomUpIterator, grammar::ContextSensitiveGrammar, state::BottomUpState, rule::Int64)::Vector{RuleNode}`: Returns the programs that can be created by applying the given rule.
- `priority_function(iter::BottomUpIterator, grammar::ContextSensitiveGrammar, program::RuleNode, state::BottomUpState)::Int64`: Returns the priority of the given program.
"""
abstract type BottomUpIterator <: ProgramIterator end

Base.@doc """
    @programiterator BasicIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

A basic implementation of the bottom-up iterator. It will enumerate all programs in increasing order based on their depth.
""" BasicIterator
@programiterator BasicIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

"""
	struct BottomUpState

Holds the state of the bottom-up iterator. This includes the priority bank, the hashes of the outputs of the programs, and the current programs that are being enumerated.
"""
struct BottomUpState
    priority_bank::Dict{Symbol, Dict{RuleNode,Int64}}
    hashes::Set{UInt}
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
    # the default order function is the BasicIterator's function
    return order(BasicIterator, grammar)
end

"""
	pick(iter::BottomUpIterator, grammar::ContextSensitiveGrammar, state::BottomUpState, rule::Int64)::Vector{RuleNode}

Returns a non-zero number of programs that can be created by applying the given rule.
"""
function pick(
    ::BottomUpIterator,
    grammar::ContextSensitiveGrammar,
    state::BottomUpState,
    rule::Int64
)
    # the default pick function is the BasicIterator's function
    return pick(BasicIterator, grammar, state, rule)
end

"""
	priority_function(iter::BottomUpIterator, grammar::ContextSensitiveGrammar, program::RuleNode, state::BottomUpState)::Int64

Returns the priority associated with the given program.
"""
function priority_function(
    ::BottomUpIterator,
    grammar::ContextSensitiveGrammar,
    program::RuleNode,
    state::BottomUpState
)
    # the default priority function is the BasicIterator's function
    return priority_function(BasicIterator, grammar, program, state)
end

"""
	order(::BasicIterator, grammar::ContextSensitiveGrammar)

Returns the non-terminal rules in the order in which they appear in the grammar.
"""
function order(
    ::BasicIterator,
    grammar::ContextSensitiveGrammar
)
    return findall(isterminal -> !isterminal, grammar.isterminal)
end

"""
	pick(::BasicIterator, grammar::ContextSensitiveGrammar, state::BottomUpState, rule::Int64)::Vector{RuleNode}

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
    candidate_programs = map(symbol -> collect(keys(get(state.priority_bank, symbol, Dict{RuleNode, Int64}()))), childtypes)

    for combination ∈ Iterators.product(candidate_programs...)
        new_program = RuleNode(rule, nothing, collect(combination))
        push!(new_programs, new_program)
    end

    return new_programs
end

"""
	priority_function(::BasicIterator, grammar::ContextSensitiveGrammar, program::RuleNode, state::BottomUpState)::Int64

Returns the depth of the RuleNode that describes the given program.
"""
function priority_function(
    ::BasicIterator,
    grammar::ContextSensitiveGrammar,
    program::RuleNode,
    state::BottomUpState
)::Int64
    max_depth::Int64 = 0
    program_symbol::Symbol = grammar.types[program.ind]

    for child ∈ program.children
        child_symbol::Symbol = grammar.types[child.ind]
        max_depth = max(max_depth, state.priority_bank[child_symbol][child])
    end

    return max_depth + 1
end

"""
	Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}

Describes the iteration for a given [`BottomUpIterator`](@ref) over the grammar. 
The iterations constructs the initial set of programs, which consists of the set of terminals.
It also constructs the ['BottomUpState'](@ref) which will be used in future iterations.
"""
function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    current_programs = Queue{RuleNode}()
    priority_bank::Base.Dict{Symbol, Dict{RuleNode,Int64}} = Dict()
	hashes::Set{UInt} = Set{UInt}()

    if iter.solver == nothing 
        iter.solver = GenericSolver(iter.grammar, iter.sym)
    end

    for terminal ∈ findall(iter.grammar.isterminal)
        current_single_program::RuleNode = RuleNode(terminal, nothing, [])
        enqueue!(current_programs, current_single_program)
    end

    state::BottomUpState = BottomUpState(priority_bank, hashes, current_programs)
    return _get_next_program(iter, state)
end

"""
	Base.iterate(iter::BottomUpIterator, state::BottomUpState)

Describes the iteration for a given [`BottomUpIterator`](@ref) over the grammar. 
It first checks for programs that were generated by not returned yet.
Otherwise, it constructs other programs by combining those from the bank and returns one of them.
"""
function Base.iterate(iter::BottomUpIterator, state::BottomUpState)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
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

Iterates through the generated programs. Once it finds a program which is not observationally equivalent to an already-returned program,
inserts it into the bank and returns it.
"""
function _get_next_program(
    iter::BottomUpIterator,
    state::BottomUpState
)::Union{Nothing,Tuple{RuleNode, BottomUpState}}
    while !isempty(state.current_programs) 
        current_program = dequeue!(state.current_programs)
        if depth(current_program) > iter.max_depth || _contains_equivalent(iter, state, current_program)
            continue
        end

        current_program_symbol::Symbol = iter.grammar.types[current_program.ind]
        symbol_dict = get!(state.priority_bank, current_program_symbol, Dict{RuleNode, Int64}())
        symbol_dict[current_program] = priority_function(iter, iter.grammar, current_program, state)

        new_state!(iter.solver, current_program)
        if isfeasible(iter.solver)
            return current_program, state
        end
    end

    return nothing
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
	_hash_outputs_for_program(iter::BottomUpIterator, program::RuleNode, problem::Problem{Vector{IOExample}})::UInt

Hashes the outputs of the programs for observing equivalent programs.
"""	
function _hash_outputs_for_program(
	iter::BottomUpIterator,
	program::RuleNode,
    problem::Problem{Vector{IOExample}}
)::UInt
    outputs = map(example -> execute_on_input(SymbolTable(iter.grammar), rulenode2expr(program, iter.grammar), example.in), problem.spec)
    return hash(outputs)
end
