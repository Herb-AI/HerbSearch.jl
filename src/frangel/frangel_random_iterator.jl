@programiterator FrAngelRandomIterator(
    rule_minsize::AbstractVector{UInt8},
    symbol_minsize::Dict{Symbol,UInt8}
)

struct FrAngelRandomIteratorState
    filtered_indices::Vector{Int16} 
    probabilities::Vector{Float16}
    cumulative_probs::Vector{Float16}
end

function Base.iterate(iter::FrAngelRandomIterator)
    max_size_estimate = length(iter.grammar.rules)
    return Base.iterate(iter, FrAngelRandomIteratorState(
        Vector{Int16}(undef, max_size_estimate), 
        Vector{Float16}(undef, max_size_estimate), 
        Vector{Float16}(undef, max_size_estimate)))
end

function Base.iterate(iter::FrAngelRandomIterator, state::FrAngelRandomIteratorState)
    return (sample!(iter.grammar, iter.sym, iter.rule_minsize, iter.symbol_minsize, state.filtered_indices, state.probabilities, state.cumulative_probs, UInt8(iter.max_depth)), state)
end

function sample!(
    grammar::AbstractGrammar, 
    symbol::Symbol, 
    rule_minsize::AbstractVector{UInt8}, 
    symbol_minsize::Dict{Symbol,UInt8}, 
    filtered_indices::Vector{Int16}, 
    probabilities::Vector{Float16}, 
    cumulative_probs::Vector{Float16},
    max_size::UInt8 = UInt8(40)
)
    max_size = max(max_size, symbol_minsize[symbol])

    empty!(filtered_indices)
    empty!(probabilities)

    push!(cumulative_probs, 0)
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