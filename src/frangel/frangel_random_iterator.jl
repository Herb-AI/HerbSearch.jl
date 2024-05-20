@programiterator FrAngelRandomIterator()

function Base.iterate(iter::FrAngelRandomIterator, state=nothing)
    rule_minsize = rules_minsize(iter.grammar) 
    
    symbol_minsize = symbols_minsize(iter.grammar, rule_minsize)

    return sample(iter.grammar, iter.sym, rule_minsize, symbol_minsize), nothing
end

function sample(grammar::AbstractGrammar, symbol::Symbol, rule_minsize::AbstractVector{Int}, symbol_minsize::Dict{Symbol,Int}, max_size=40)
    max_size = max(max_size, symbol_minsize[symbol])
    
    rules_for_symbol = grammar[symbol]
    log_probs = grammar.log_probabilities
    filtered_indices = filter(i -> return_type(grammar, rules_for_symbol[i]) == symbol && rule_minsize[rules_for_symbol[i]] ≤ max_size, eachindex(rules_for_symbol))
    
    possible_rules = [rules_for_symbol[i] for i in filtered_indices]
    weights = Weights(exp.(log_probs[filtered_indices]))
    
    rule_index = StatsBase.sample(possible_rules, weights)
    rule_node = RuleNode(rule_index)

    if !grammar.isterminal[rule_index]
        sizes = random_partition(grammar, rule_index, max_size, symbol_minsize)

        for (index, child_type) in enumerate(child_types(grammar, rule_index))
            push!(rule_node.children, sample(grammar, child_type, rule_minsize, symbol_minsize, sizes[index]))
        end
    end

    rule_node
end