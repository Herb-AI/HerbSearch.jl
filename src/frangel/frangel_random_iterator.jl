@programiterator FrAngelRandomIterator(
    rule_minsize::AbstractVector{UInt8},
    symbol_minsize::Dict{Symbol,UInt8}
)

function Base.iterate(iter::FrAngelRandomIterator, state=nothing)
    return (sample(iter.grammar, iter.sym, iter.rule_minsize, iter.symbol_minsize), state)
end

function sample(grammar::AbstractGrammar, symbol::Symbol, rule_minsize::AbstractVector{UInt8}, symbol_minsize::Dict{Symbol,UInt8}, max_size::UInt8 = UInt8(40))
    max_size = max(max_size, symbol_minsize[symbol])

    filtered_indices = Int16[]
    probabilities = Float16[]
    for i in grammar[symbol]
        if rule_minsize[i] ≤ max_size
            push!(filtered_indices, i)
            push!(probabilities, grammar.log_probabilities[i])
        end
    end

    cumulative_probs = cumsum(probabilities)
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

        for (index, child_type) in enumerate(child_types(grammar, Int(rule_index)))
            push!(rule_node.children, sample(grammar, child_type, rule_minsize, symbol_minsize, sizes[index]))
        end
    end

    rule_node
end