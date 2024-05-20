@programiterator FrAngelRandomIterator()

function Base.iterate(iter::FrAngelRandomIterator, state=nothing)
    rule_minsize = rules_minsize(iter.grammar) 
    
    symbol_minsize = symbols_minsize(iter.grammar, rule_minsize)

    return sample(iter.grammar, iter.sym, rule_minsize, symbol_minsize), nothing
end

function sample(grammar::AbstractGrammar, symbol::Symbol, rule_minsize::AbstractVector{Int}, symbol_minsize::Dict{Symbol,Int}, max_size=40)
    max_size = max(max_size, symbol_minsize[symbol])
    
    rules_for_symbol = grammar[symbol]
    filtered_indices = filter(i -> return_type(grammar, rules_for_symbol[i]) == symbol && rule_minsize[rules_for_symbol[i]] ≤ max_size, eachindex(rules_for_symbol))
    
    rule_index = -1
    r = rand()
    sum_prob = 0.0

    for i in filtered_indices
        prob = grammar.log_probabilities[i]
        sum_prob += prob
        r -= prob
        if r ≤ 0
            rule_index = rules_for_symbol[i]
            break
        end
    end

    if rule_index == -1
        r = rand() * sum_prob
        for i in filtered_indices
            r -= grammar.log_probabilities[i]
            if r ≤ 0
                rule_index = rules_for_symbol[i]
                break
            end
        end
    end

    rule_node = RuleNode(rule_index)

    if !grammar.isterminal[rule_index]
        sizes = random_partition(grammar, rule_index, max_size, symbol_minsize)

        for (index, child_type) in enumerate(child_types(grammar, rule_index))
            push!(rule_node.children, sample(grammar, child_type, rule_minsize, symbol_minsize, sizes[index]))
        end
    end

    rule_node
end