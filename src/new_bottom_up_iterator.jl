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
    @programiterator DepthIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

A basic implementation of the bottom-up iterator. It will enumerate all programs in increasing order based on their depth.
""" DepthIterator
@programiterator DepthIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

struct BottomUpState
    bank::Any,
    data::Any,
    hash_set::Set{UInt}
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
)::Dict{Symbol, RuleNode}
    
end

function Base.iterate(iter::BottomUpIterator)::Union{Nothing,Tuple{RuleNode,BottomUpState}}
    priority_bank::Base.Dict{Symbol, Dict{RuleNode,Int64}} = Dict()
	hashes::Set{UInt} = Set{UInt}()
    current_programs = Queue{RuleNode}()

    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

    for terminal ∈ findall(grammar.isterminal)
        current_single_program::RuleNode = RuleNode(terminal, nothing, [])
        enqueue!(current_programs, current_single_program)
    end

    state::BottomUpState = BottomUpState(priority_bank, hashes, current_programs)
    return _get_next_program(iter, state)
end