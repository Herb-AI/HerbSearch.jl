"""
    grammar_to_list(grammar::ContextSensitiveGrammar)

Converts a grammar to a list of strings that represent each rule. The cost of each rule is computed using calculate_rule_cost.
"""
function grammar_to_list(grammar::ContextSensitiveGrammar)
    rules = Vector{String}()
    for i in eachindex(grammar.rules)
        type = grammar.types[i]
        rule = grammar.rules[i]
        cost = HerbSearch.calculate_rule_cost(i, grammar)
        push!(rules, "rule_cost $cost : $type => $rule")
    end
    return rules
end