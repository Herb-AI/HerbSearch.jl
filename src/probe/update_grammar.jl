
"""
    update_grammar(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCache}, examples::Vector{<:IOExample})

Update the given `grammar` using the provided `PSols_with_eval_cache` and `examples`.

# Arguments
- `grammar::ContextSensitiveGrammar`: The grammar to be updated.
- `PSols_with_eval_cache::Vector{ProgramCache}`: The program solutions with evaluation cache.
- `examples::Vector{<:IOExample}`: The input-output examples.

"""
function update_grammar(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCache}, examples::Vector{<:IOExample})
    sum = 0
    for rule_index in eachindex(grammar.rules) # iterate for each rule_index 
        highest_correct_nr = 0
        for psol in PSols_with_eval_cache
            program = psol.program
            len_correct_examples = length(psol.correct_examples)
            # check if the program tree has rule_index somewhere inside it using a recursive function
            if contains_rule(program, rule_index) && len_correct_examples > highest_correct_nr
                highest_correct_nr = len_correct_examples
            end
        end
        fitnes = highest_correct_nr / length(examples)
        p_uniform = 1 / length(grammar.rules)

        # compute (log2(p_u) ^ (1 - fit)) = (1-fit) * log2(p_u)
        sum += p_uniform^(1 - fitnes)
        log_prob = ((1 - fitnes) * log(p_uniform))
        grammar.log_probabilities[rule_index] = log_prob
    end
    total_sum = 0
    for rule_index in eachindex(grammar.rules)
        grammar.log_probabilities[rule_index] = grammar.log_probabilities[rule_index] - log(sum)
        total_sum += exp.(grammar.log_probabilities[rule_index])
    end
    @assert abs(total_sum - 1) <= 1e-4 "Total sum is $(total_sum) "
end

"""
    contains_rule(program::RuleNode, rule_index::Int)

Check if a given `RuleNode` contains has used a derivation rule with the specified `rule_index`

# Arguments
- `program::RuleNode`: The `RuleNode` to check.
- `rule_index::Int`: The index of the rule to check for.

"""
function contains_rule(program::RuleNode, rule_index::Int)
    if program.ind == rule_index # if the rule is good return true
        return true
    else
        for child in program.children
            if contains_rule(child, rule_index)  # if a child has that rule then return true
                return true
            end
        end
        return false # if no child has that rule return false
    end
end
