Base.@doc """
    @programiterator BUDepthIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

A basic implementation of the bottom-up iterator. It will enumerate all programs in increasing order based on their depth.
""" DepthIterator
@programiterator BUDepthIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

struct BUDepthBank <: BottomUpBank
    rulenodes_by_symbol::Dict{Symbol, Vector{RuleNode}}
end

mutable struct BUDepthData <: BottomUpData
    next_programs_iterable::Any
    next_programs_result::Union{Nothing, Tuple{Tuple{Int, Any}, Any}}

    new_programs::Vector{RuleNode}

    rules::Queue{Int}
    depth::Int
end

"""
	order(iter::DepthIterator)

Returns the non-terminal rules in the order in which they appear in the grammar.
"""
function order(
    iter::BUDepthIterator
)::Queue{Int}
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)
    rules::Queue{Int} = Queue{Int}()

    for (rule_index, is_terminal) ∈ enumerate(grammar.isterminal)
        if !is_terminal
            enqueue!(rules, rule_index)
        end
    end

    return rules
end

function init_bank(
    iter::BUDepthIterator
)::BUDepthBank
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)
    rulenodes_by_symbol::Dict{Symbol, Vector{RuleNode}} = Dict{Symbol, Vector{RuleNode}}()

    for symbol ∈ grammar.types
        rulenodes_by_symbol[symbol] = Vector{RuleNode}()
    end

    return BUDepthBank(rulenodes_by_symbol)
end

function init_data(
    iter::BUDepthIterator
)::BUDepthData
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

    next_programs_iterable::Vector{Tuple{Int, Vector{RuleNode}}} = Vector{Tuple{Int, Vector{RuleNode}}}()
    for terminal ∈ findall(grammar.isterminal)
        push!(next_programs_iterable, (terminal, []))
    end
    next_programs_result = iterate(next_programs_iterable)

    return BUDepthData(next_programs_iterable, next_programs_result, Vector{RuleNode}(), Queue{Int}(), 1)
end

function create_program(
    iter::BUDepthIterator,
    bank::BUDepthBank,
    data::BUDepthData
)::Union{Nothing, RuleNode}
    rulenodes_by_symbol::Dict{Symbol, Vector{RuleNode}} = bank.rulenodes_by_symbol

    while data.next_programs_result === nothing
        grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

        if isempty(data.rules)
            # New depth reached, so we can add the new programs to the bank
            _increase_depth!(iter, bank, data, grammar)

            if data.depth > get_max_depth(iter.solver)
                return nothing
            end
        end

        current_rule::Int = dequeue!(data.rules)

        childtypes::Vector{Symbol} = grammar.childtypes[current_rule]
        children_combinations::Vector{Vector{RuleNode}} = map(symbol -> rulenodes_by_symbol[symbol], childtypes)
        
        data.next_programs_iterable = Iterators.product(current_rule, Iterators.product(children_combinations...))
        data.next_programs_result = iterate(data.next_programs_iterable)
    end

    ((next_program_rule, next_program_children), next_program_state) = data.next_programs_result
    data.next_programs_result = iterate(data.next_programs_iterable, next_program_state)

    return RuleNode(next_program_rule, nothing, collect(next_program_children))

end

function update_state!(
    ::BUDepthIterator,
    ::BUDepthBank,
    data::BUDepthData,
    program::RuleNode
)::Nothing
    push!(data.new_programs, program)
    return nothing
end

function _increase_depth!(
    iter::BUDepthIterator,
    bank::BUDepthBank,
    data::BUDepthData,
    grammar::ContextSensitiveGrammar
)::Nothing
    data.rules = order(iter)
    data.depth += 1

    rulenodes_by_symbol::Dict{Symbol, Vector{RuleNode}} = bank.rulenodes_by_symbol

    for program ∈ data.new_programs
        symbol::Symbol = grammar.types[program.ind]
        push!(rulenodes_by_symbol[symbol], program)
    end

    empty!(data.new_programs)
    return nothing
end
