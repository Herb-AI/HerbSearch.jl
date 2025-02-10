Base.@doc """
    @programiterator BUUniformIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

Implementation of the `BottomUpIterator`. Iterates through complete programs in increasing order of their depth.
More memory efficient than the plain BUDepthIterator since it stores `UniformTrees` in the bank instead of `RuleNodes`.
""" BUUniformIterator
@programiterator BUUniformIterator() <: BottomUpIterator

"""
    struct BUUniformBank <: BottomUpBank

Specialization of `BottomUpState`'s `BottomUpBank` type. Holds a `Dict` mapping `Symbols` to `Vectors` of `RuleNodes` of that `Symbol`.
"""
struct BUUniformBank <: BottomUpBank
    tree_shapes_by_symbol::Dict{Symbol, Vector{UniformHole}}
end

"""
    struct BUDepthData <: BottomUpData

Specialization of `BottomUpState`'s `BottomUpData` type. Contains the following:
* `nested_rulenode_iterator::NestedRulenodeIterator`: Iterator generating `RuleNodes` using a grammar rule to combine existing `RuleNodes` from the `bank`.
* `new_programs::Vector{RuleNode}`: Programs generated at the current depth level. Will be appended to the `bank` when starting a new depth level.
* `rules::Queue{Int}`: Grammar rules left to be used at the current depth level. 
* `depth::Int`: Current depth.
"""
mutable struct BUUniformData <: BottomUpData
    nested_uniform_iterator::Union{NestedUniformIterator, Nothing}
    new_tree_shapes::Vector{UniformHole}
    uniform_roots::Queue{UniformHole}
    depth::Int
end

"""
	init_bank(iter::BUDepthIterator)::BUDepthBank

Returns an initialized object of type `BUDepthBank`. For each symbol in the grammar (i.e. key in the dictionary), an empty `Vector{RuleNode}` (i.e. value in the dictionary) is allocated.
"""
function init_bank(
    iter::BUUniformIterator
)::BUUniformBank
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)
    rulenodes_by_symbol::Dict{Symbol, Vector{UniformHole}} = Dict{Symbol, Vector{UniformHole}}()

    for symbol ∈ grammar.types
        rulenodes_by_symbol[symbol] = Vector{UniformHole}()
    end

    return BUUniformBank(rulenodes_by_symbol)
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
    iter::BUUniformIterator
)::BUUniformData
    depth::Int = 1

    uniform_roots::Queue{UniformHole} = _create_uniform_tree_root_nodes(iter, terminals=true)
    @assert !isempty(uniform_roots) "The grammar doesn't contain any terminal symbols."

    return BUUniformData(nothing, Vector{UniformHole}(), uniform_roots, depth)
end

"""
    create_program!(iter::BUDepthIterator, bank::BUDepthBank, data::BUDepthData)::Union{Nothing, RuleNode}

Returns the next program in `BUDepthIterator`'s iteration. Performs the following steps:
1. Check whether `data.nested_rulenode_iterator` contains any program.
2. Otherwise, pick the next rule from `data.rules` and generate all combinations of `RuleNodes` from the bank that could be combined using this rule.
3. If `data.rules` is empty, call `_increase_depth!` and go to step 2.
"""
function create_program!(
    iter::BUUniformIterator,
    bank::BUUniformBank,
    data::BUUniformData
)::Union{Nothing, RuleNode}
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

    # This happens during the first call to create_program!
    if isnothing(data.nested_uniform_iterator)
        data.nested_uniform_iterator = _create_nested_uniform_iterator!(iter, bank, data, grammar)
    end

    program::Union{RuleNode, Nothing} = get_next_rulenode!(data.nested_uniform_iterator)
    while isnothing(program)
        # Add the uniform tree shapes from the current nested iterator to the bank.
        append!(data.new_tree_shapes, get_uniform_trees(data.nested_uniform_iterator))

        if isempty(data.uniform_roots)
            _increase_depth!(iter, bank, data, grammar)

            if data.depth > get_max_depth(iter.solver)
                return nothing
            end
        end

        data.nested_uniform_iterator = _create_nested_uniform_iterator!(iter, bank, data, grammar)
        program = get_next_rulenode!(data.nested_uniform_iterator)
    end

    return program
end

"""
    update_state!(::BUUniformIterator, ::BUUniformBank, data::BUUniformData, program::RuleNode)::Nothing

No-operation in the case of the Bottom-Up Uniform Iterator.
"""
function update_state!(
    ::BUUniformIterator,
    ::BUUniformBank,
    data::BUUniformData,
    program::RuleNode
)::Nothing
end

function _create_uniform_tree_root_nodes(
    iter::BUUniformIterator;
    terminals::Bool=false
)::Queue{UniformHole}
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)
    rules::BitVector = grammar.isterminal
    if !terminals
        rules = rules .⊻ BitVector(fill(true, length(rules)))
    end

    return _partition_rules(iter, rules)
end

function _partition_rules(
    iter::BUUniformIterator,
    rules::BitVector
)::Queue{UniformHole}
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)
    
    dict::Dict{Symbol, BitVector} = Dict{Symbol, BitVector}()
    for lhs ∈ unique(grammar.types)
        dict[lhs] = BitVector(fill(false, length(rules)))
    end
    
    for rule ∈ findall(rules)
        lhs = grammar.types[rule]
        dict[lhs][rule] = true
    end

    hole_domains::Vector{BitVector} = Vector{BitVector}()
    for (_, lhs_rules) ∈ dict
        append!(hole_domains, partition(Hole(lhs_rules), grammar))
    end
    
    uniform_roots::Queue{UniformHole} = Queue{UniformHole}()
    for domain ∈ hole_domains
        enqueue!(uniform_roots, UniformHole(domain, Vector{UniformHole}()))
    end

    return uniform_roots
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
    iter::BUUniformIterator,
    bank::BUUniformBank,
    data::BUUniformData,
    grammar::ContextSensitiveGrammar
)::Nothing
    data.uniform_roots = _create_uniform_tree_root_nodes(iter)
    data.depth += 1

    tree_shapes_by_symbol::Dict{Symbol, Vector{UniformHole}} = bank.tree_shapes_by_symbol

    for tree_shape ∈ data.new_tree_shapes
        symbol::Symbol = return_type(grammar, tree_shape)
        push!(tree_shapes_by_symbol[symbol], tree_shape)
    end

    empty!(data.new_tree_shapes)
    return nothing
end

"""
    _create_nested_rulenode_iterator(::BUDepthIterator, bank::BUDepthBank, data::BUDepthData, grammar::ContextSensitiveGrammar)::NestedRulenodeIterator

Creates a new `NestedRulenodeIterator` iterating through `RuleNodes` having the root the current rule in `data.rules`.
The childrens of the root will be all combinations of `RuleNodes` of matching `Symbol` types from the `bank`. 
"""
function _create_nested_uniform_iterator!(
    ::BUUniformIterator,
    bank::BUUniformBank,
    data::BUUniformData,
    grammar::ContextSensitiveGrammar,
)::NestedUniformIterator
    uniform_root::UniformHole = dequeue!(data.uniform_roots)
    first_rule::Int = findfirst(uniform_root.domain)

    if grammar.isterminal[first_rule]
        return NestedUniformIterator([Vector{UniformHole}()], uniform_root, grammar)
    end

    childtypes::Vector{Symbol} = grammar.childtypes[first_rule]
    children_combinations::Vector{Vector{UniformHole}} = map(symbol -> bank.tree_shapes_by_symbol[symbol], childtypes)

    return NestedUniformIterator(Iterators.product(children_combinations...), uniform_root, grammar)
end
