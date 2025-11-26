struct RedundantValues
    expr::Vector{Any}
end

function get_terminals(grammar::AbstractGrammar)
    return [grammar.rules[r] for r in 1:length(grammar.rules) if isterminal(grammar, r)]
end