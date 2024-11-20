Base.@doc """
    @programiterator BUDepthIterator(problem::Union{Nothing, Problem{Vector{IOExample}}}=nothing, obs_equivalence::Bool=false) <: BottomUpIterator

Implementation of the `BottomUpIterator`. Iterates through complete programs in increasing order of their depth.
""" BUDepthIterator
@programiterator BUDepthIterator(
    problem::Union{Nothing, Problem{Vector{IOExample}}}=nothing,
    obs_equivalence::Bool=false
) <: BottomUpIterator

"""
    struct BUDepthBank <: BottomUpBank

Specialization of `BottomUpState`'s `BottomUpBank` type. Holds a `Dict` mapping `Symbols` to `Vectors` of `RuleNodes` of that `Symbol`.
"""
struct BUDepthBank <: BottomUpBank
    rulenodes_by_symbol::Dict{Symbol, Vector{RuleNode}}
end

"""
    struct BUDepthData <: BottomUpData

Specialization of `BottomUpState`'s `BottomUpData` type. Contains the following:
* `nested_rulenode_iterator::NestedRulenodeIterator`: Iterator generating `RuleNodes` using a grammar rule to combine existing `RuleNodes` from the `bank`.
* `new_programs::Vector{RuleNode}`: Programs generated at the current depth level. Will be appended to the `bank` when starting a new depth level.
* `rules::Queue{Int}`: Grammar rules left to be used at the current depth level. 
* `depth::Int`: Current depth.
"""
mutable struct BUDepthData <: BottomUpData
    nested_rulenode_iterator::NestedRulenodeIterator
    new_programs::Vector{RuleNode}
    rules::Queue{Int}
    depth::Int
end

"""
	order(iter::BUDepthIterator)::Queue{Int}

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

"""
	init_bank(iter::BUDepthIterator)::BUDepthBank

Returns an initialized object of type `BUDepthBank`. For each symbol in the grammar (i.e. key in the dictionary), an empty `Vector{RuleNode}` (i.e. value in the dictionary) is allocated.
"""
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

"""
    init_data(iter::BUDepthIterator)::BUDepthData

Returns an initialized object of type `BUDepthData`. The initialization consists of the following:
* `nested_rulenode_iterator` is set to an empty `NestedRulenodeIterator`.
* `rules` contains the indeces of terminal rules in the grammar.
* `new_programs` is an empty `Vector{RuleNode}`.
* `depth` is set to 1.
"""
function init_data(
    iter::BUDepthIterator
)::BUDepthData
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

    empty_nested_iterator::NestedRulenodeIterator = NestedRulenodeIterator()
    depth::Int = 1

    rules::Queue{Int} = Queue{Int}()
    for (rule_index, is_terminal) ∈ enumerate(grammar.isterminal)
        if is_terminal
            enqueue!(rules, rule_index)
        end
    end

    return BUDepthData(empty_nested_iterator, Vector{RuleNode}(), rules, depth)
end

"""
    create_program!(iter::BUDepthIterator, bank::BUDepthBank, data::BUDepthData)::Union{Nothing, RuleNode}

Returns the next program in `BUDepthIterator`'s iteration. Performs the following steps:
1. Check whether `data.nested_rulenode_iterator` contains any program.
2. Otherwise, pick the next rule from `data.rules` and generate all combinations of `RuleNodes` from the bank that could be combined using this rule.
3. If `data.rules` is empty, call `_increase_depth!` and go to step 2.
"""
function create_program!(
    iter::BUDepthIterator,
    bank::BUDepthBank,
    data::BUDepthData
)::Union{Nothing, RuleNode}
    program::Union{RuleNode, Nothing} = get_next_rulenode!(data.nested_rulenode_iterator)

    while isnothing(program)
        grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

        if isempty(data.rules)
            _increase_depth!(iter, bank, data, grammar)

            if data.depth > get_max_depth(iter.solver)
                return nothing
            end
        end

        data.nested_rulenode_iterator = _create_nested_rulenode_iterator(iter, bank, data, grammar)
        program = get_next_rulenode!(data.nested_rulenode_iterator)
    end

    return program
end

"""
update_state!(::BUDepthIterator, ::BUDepthBank, data::BUDepthData, program::RuleNode)::Nothing

Appends the `program` to `data.new_programs`.
"""
function update_state!(
    ::BUDepthIterator,
    ::BUDepthBank,
    data::BUDepthData,
    program::RuleNode
)::Nothing
    push!(data.new_programs, program)
    return nothing
end

"""
    _create_nested_rulenode_iterator(::BUDepthIterator, bank::BUDepthBank, data::BUDepthData, grammar::ContextSensitiveGrammar)::NestedRulenodeIterator

Creates a new `NestedRulenodeIterator` iterating through `RuleNodes` having the root the current rule in `data.rules`.
The childrens of the root will be all combinations of `RuleNodes` of matching `Symbol` types from the `bank`. 
"""
function _create_nested_rulenode_iterator(
    ::BUDepthIterator,
    bank::BUDepthBank,
    data::BUDepthData,
    grammar::ContextSensitiveGrammar,
)::NestedRulenodeIterator
    rule::Int = dequeue!(data.rules)

    if grammar.isterminal[rule]
        return NestedRulenodeIterator([Tuple{}()], rule)
    end

    childtypes::Vector{Symbol} = grammar.childtypes[rule]
    children_combinations::Vector{Vector{RuleNode}} = map(symbol -> bank.rulenodes_by_symbol[symbol], childtypes)

    return NestedRulenodeIterator(Iterators.product(children_combinations...), rule)
end

"""
    _increase_depth!(iter::BUDepthIterator, bank::BUDepthBank, data::BUDepthData, grammar::ContextSensitiveGrammar)::Nothing

Performs the following steps required when the depth is increased:
* Increase `data.depth`.
* Create a new `data.rules` queue consisting of the indices of non-terminal rules in the grammar.
* Copy all programs from `data.new_programs` to the `bank`.
* Go to Step 2.
"""
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
