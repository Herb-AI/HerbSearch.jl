@programiterator ExperimentalRandomIterator(
    rule_minsize::AbstractVector{UInt8},
    symbol_minsize::Dict{Symbol,UInt8},
    basic_rules_count::Int
)

struct ExperimentalRandomIteratorState
    filtered_indices::Vector{Int16}
    probabilities::Vector{Float16}
    cumulative_probs::Vector{Float16}
    rule_usage_count::Vector{UInt32}
end

function Base.iterate(iter::ExperimentalRandomIterator)
    symbol_inverse_counts_sum = Dict{Symbol,Float16}()
    return Base.iterate(iter, ExperimentalRandomIteratorState(Vector{Int16}(), Vector{Float16}(), Vector{Float16}(), vec(zeros(UInt32, iter.basic_rules_count, 1))))
end

function Base.iterate(iter::ExperimentalRandomIterator, state::ExperimentalRandomIteratorState)
    return (sample!(iter.solver.grammar, get_starting_symbol(iter.solver), iter.rule_minsize, iter.symbol_minsize, 
        state.filtered_indices, state.probabilities, state.cumulative_probs, state.rule_usage_count, UInt8(iter.solver.max_depth)), state)
end

function sample!(
    grammar::AbstractGrammar,
    symbol::Symbol,
    rule_minsize::AbstractVector{UInt8},
    symbol_minsize::Dict{Symbol,UInt8},
    filtered_indices::Vector{Int16},
    probabilities::Vector{Float16},
    cumulative_probs::Vector{Float16},
    rule_usage_count::Vector{UInt32},
    max_size::UInt8=UInt8(40)
)::RuleNode
    max_size = max(max_size, symbol_minsize[symbol])
    empty!(filtered_indices)
    empty!(probabilities)
    inverse_counts_sum = 0.0
    updated_indices = Vector{Int}()
    # Only consider rules that have defined a minimal size defined
    for i in grammar[symbol]
        if rule_minsize[i] ≤ max_size
            push!(filtered_indices, i)
            if i ≤ length(rule_usage_count)
                inverse_counts_sum += (1 / (1 + rule_usage_count[i]))
                push!(probabilities, grammar.log_probabilities[i] * (1 / (1 + rule_usage_count[i])))
                push!(updated_indices, length(probabilities))
            else 
                push!(probabilities, grammar.log_probabilities[i])
            end
        end
    end
    for i in updated_indices
        probabilities[i] = probabilities[i] / inverse_counts_sum    
    end

    empty!(cumulative_probs)
    append!(cumulative_probs, cumsum(probabilities))
    total_prob = cumulative_probs[end]
    # Pick randomly a number
    r = rand(Float16) * total_prob
    rule_index = -1
    # Find the respective rulenode based on cumulative probability
    for (index, cum_prob) in enumerate(cumulative_probs)
        if r ≤ cum_prob
            rule_index = filtered_indices[index]
            break
        end
    end
    rule_node = RuleNode(Int(rule_index))
    if rule_index <= length(rule_usage_count)
        rule_usage_count[rule_index] += 1
    end
    # If the rule is not terminal, partition remaining sizes to children and generate them
    if !grammar.isterminal[rule_index]
        sizes = random_partition(grammar, rule_index, max_size, symbol_minsize)
        children_types = child_types(grammar, Int(rule_index))

        rule_node.children = Vector{RuleNode}(undef, length(children_types))

        for (index, child_type) in enumerate(children_types)
            rule_node.children[index] = sample!(
                grammar, child_type, rule_minsize, symbol_minsize,
                filtered_indices, probabilities, cumulative_probs, rule_usage_count, sizes[index]
            )
        end
    end
    rule_node
end