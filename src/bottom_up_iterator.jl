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

Base.@doc """
    @programiterator DepthIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

A basic implementation of the bottom-up iterator. It will enumerate all programs in increasing order based on their depth.
""" DepthIterator
@programiterator DepthIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

mutable struct BottomUpState
    bank::Any
    data::Any
    hash_set::Set{UInt}
end

mutable struct DepthIteratorData
    next_programs_iterable::Any
    next_programs_result::Union{Nothing, Tuple{Tuple{Int, Any}, Any}}

    new_programs::Vector{RuleNode}

    ordered_rules::Vector{Int}
    current_rule::Int
    depth::Int
end

"""
	priority_function(iter::DepthIterator, program::RuleNode)::Int64

Returns the depth of the RuleNode that describes the given program.
"""
function cost_function(
    iter::DepthIterator,
    program::RuleNode
)
    return depth(program)
end

"""
	order(iter::DepthIterator)

Returns the non-terminal rules in the order in which they appear in the grammar.
"""
function order(
    iter::DepthIterator
)
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

    return findall(isterminal -> !isterminal, grammar.isterminal)
end

function init_bank(
    iter::DepthIterator
)::Dict{Symbol, Vector{RuleNode}}
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)
    bank::Dict{Symbol, Vector{RuleNode}} = Dict{Symbol, Vector{RuleNode}}()

    for symbol ∈ grammar.types
        bank[symbol] = Vector{RuleNode}()
    end

    return bank
end

function init_data(
    iter::DepthIterator
)::DepthIteratorData
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

    next_programs_iterable::Vector{Tuple{Int, Vector{RuleNode}}} = Vector{Tuple{Int, Vector{RuleNode}}}()
    for terminal ∈ findall(grammar.isterminal)
        push!(next_programs_iterable, (terminal, []))
    end

    next_programs_result = iterate(next_programs_iterable)

    new_programs::Vector{RuleNode} = Vector{RuleNode}()

    ordered_rules::Vector{Int} = order(iter)
    current_rule::Int = 0

    # TODO: change the implementation to start with depth at 1
    return DepthIteratorData(next_programs_iterable, next_programs_result, new_programs, ordered_rules, current_rule, 1)
end

function _update_bank!(
    bank::Dict{Symbol, Vector{RuleNode}},
    data::DepthIteratorData,
    grammar::ContextSensitiveGrammar
)::Nothing
    for program ∈ data.new_programs
        symbol::Symbol = grammar.types[program.ind]
        push!(bank[symbol], program)
    end

    data.new_programs = Vector{RuleNode}()
    return nothing
end

function create_program(
    iter::DepthIterator,
    bank::Dict{Symbol, Vector{RuleNode}},
    data::DepthIteratorData
)::Union{Nothing, RuleNode}
    while data.next_programs_result === nothing
        grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

        data.current_rule += 1
        if data.current_rule > length(data.ordered_rules)
            data.depth += 1
            if data.depth > get_max_depth(iter.solver)
                return nothing
            end

            # New depth reached, so we can add the new programs to the bank
            _update_bank!(bank, data, grammar)
            data.current_rule = 1
        end

        childtypes::Vector{Symbol} = grammar.childtypes[data.ordered_rules[data.current_rule]]
        children_combinations::Vector{Vector{RuleNode}} = map(symbol -> bank[symbol], childtypes)
        
        data.next_programs_iterable = Iterators.product(data.ordered_rules[data.current_rule], Iterators.product(children_combinations...))
        data.next_programs_result = iterate(data.next_programs_iterable)
    end

    ((next_program_rule, next_program_children), next_program_state) = data.next_programs_result
    data.next_programs_result = iterate(data.next_programs_iterable, next_program_state)

    return RuleNode(next_program_rule, nothing, collect(next_program_children))

end

function update_state!(
    iter::DepthIterator,
    bank::Dict{Symbol, Vector{RuleNode}},
    data::DepthIteratorData,
    program::RuleNode
)::Nothing
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

    symbol::Symbol = grammar.types[program.ind]
    push!(data.new_programs, program)

    return nothing
end

function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

    bank::Any = init_bank(iter)
    data::Any = init_data(iter)
    hash_set::Set{UInt64} = Set{UInt64}()

    state::BottomUpState = BottomUpState(bank, data, hash_set)
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