Base.@doc """
    @programiterator FrAngelRandomIterator(rule_minsize::AbstractVector{UInt8}, symbol_minsize::Dict{Symbol,UInt8})

A custom iterator for FrAngel that generates random programs.

# Arguments
- `rule_minsize`: A vector of minimum sizes for each production rule in the grammar. Can be obtained from [`rules_minsize`](@ref).
- `symbol_minsize`: A dictionary with the minimum size achievable for each symbol in the grammar. Can be obtained from [`symbols_minsize`](@ref).
""" FrAngelRandomIterator

@programiterator FrAngelRandomIterator(
    rule_minsize::AbstractVector{UInt8},
    symbol_minsize::Dict{Symbol,UInt8}
)


"""
    struct FrAngelRandomIteratorState

A struct representing the state of a FrAngel random iterator.

# Fields
- `filtered_indices`: Indices of the rules that can be used for generation.
- `probabilities`: The probabilities of each rule to be selected.
- `cumulative_probs`: A cumulative probability vector of `probabilities`.

"""
struct FrAngelRandomIteratorState
    filtered_indices::Vector{Int16}
    probabilities::Vector{Float16}
    cumulative_probs::Vector{Float16}
end

function Base.iterate(iter::FrAngelRandomIterator)
    # max_size_estimate = length(iter.grammar.rules)
    return Base.iterate(iter, FrAngelRandomIteratorState(Vector{Int16}(), Vector{Float16}(), Vector{Float16}()))
end

function Base.iterate(iter::FrAngelRandomIterator, state::FrAngelRandomIteratorState)
    return (sample!(iter.grammar, iter.sym, iter.rule_minsize, iter.symbol_minsize, state.filtered_indices, state.probabilities, state.cumulative_probs, UInt8(iter.max_depth)), state)
end


"""
    sample!(grammar::AbstractGrammar, symbol::Symbol, rule_minsize::AbstractVector{UInt8}, symbol_minsize::Dict{Symbol,UInt8},
        filtered_indices::Vector{Int16}, probabilities::Vector{Float16}, cumulative_probs::Vector{Float16}, max_size::UInt8=UInt8(40))::RuleNode

Sample a random rule from the grammar based on the given symbol and maximum size.

# Arguments
- `grammar`: The grammar to sample from.
- `symbol`: The symbol representing the program's type.
- `rule_minsize`: A vector of minimum sizes for each production rule in the grammar. Can be obtained from [`rules_minsize`](@ref).
- `symbol_minsize`: A dictionary with the minimum size achievable for each symbol in the grammar. Can be obtained from [`symbols_minsize`](@ref).
- `filtered_indices`: Indices of the rules that can be used for generation.
- `probabilities`: The probabilities of each rule to be selected.
- `cumulative_probs`: A cumulative probability vector of `probabilities`.
- `max_size`: The maximum size allowed for the program.

# Returns
- `rule_node`: The sampled rule as a `RuleNode`.

"""
function sample!(
    grammar::AbstractGrammar,
    symbol::Symbol,
    rule_minsize::AbstractVector{UInt8},
    symbol_minsize::Dict{Symbol,UInt8},
    filtered_indices::Vector{Int16},
    probabilities::Vector{Float16},
    cumulative_probs::Vector{Float16},
    max_size::UInt8=UInt8(40)
)::RuleNode
    max_size = max(max_size, symbol_minsize[symbol])

    empty!(filtered_indices)
    empty!(probabilities)

    for i in grammar[symbol]
        if rule_minsize[i] ≤ max_size
            push!(filtered_indices, i)
            push!(probabilities, grammar.log_probabilities[i])
        end
    end

    empty!(cumulative_probs)
    append!(cumulative_probs, cumsum(probabilities))
    total_prob = cumulative_probs[end]

    r = rand(Float16) * total_prob
    rule_index = -1

    for (index, cum_prob) in enumerate(cumulative_probs)
        if r ≤ cum_prob
            rule_index = filtered_indices[index]
            break
        end
    end

    rule_node = RuleNode(Int(rule_index))

    if !grammar.isterminal[rule_index]
        sizes = random_partition(grammar, rule_index, max_size, symbol_minsize)
        children_types = child_types(grammar, Int(rule_index))

        rule_node.children = Vector{RuleNode}(undef, length(children_types))

        for (index, child_type) in enumerate(children_types)
            rule_node.children[index] = sample!(
                grammar, child_type, rule_minsize, symbol_minsize,
                filtered_indices, probabilities, cumulative_probs, sizes[index]
            )
        end
    end

    rule_node
end