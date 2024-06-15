using Random

"""
    update_grammar(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCache}, examples::Vector{<:IOExample})

Update the given `grammar` using the provided `PSols_with_eval_cache` and `examples`.

# Arguments
- `grammar::ContextSensitiveGrammar`: The grammar to be updated.
- `PSols_with_eval_cache::Vector{ProgramCache}`: The program solutions with evaluation cache.
- `examples::Vector{<:IOExample}`: The input-output examples.

"""
function update_grammar!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCache}, examples::Vector{<:IOExample})
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
        log_prob = ((1 - fitnes) * log2(p_uniform))
        grammar.log_probabilities[rule_index] = log_prob
    end
    total_sum = 0
    for rule_index in eachindex(grammar.rules)
        grammar.log_probabilities[rule_index] -= log2(sum)
        total_sum += exp2(grammar.log_probabilities[rule_index])
    end
    @assert abs(total_sum - 1) <= 1e-4 "Total sum is $(total_sum) "
end

function update_grammar!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCacheTrace})
    sum = 0
    for rule_index in eachindex(grammar.rules)
        best_reward = 0
        for psol in PSols_with_eval_cache
            program = psol.program.children[end]
            if program.ind != 2
                program = program.children[end]
            end
            reward = psol.reward
            # check if the program tree has rule_index somewhere inside it using a recursive function
            if contains_rule(program, rule_index) && reward > best_reward
                best_reward = reward
            end
        end
        # fitness higher is better
        # TODO: think about better thing here
        fitness = min(best_reward / 100, 1)

        p_current = exp2(grammar.log_probabilities[rule_index])

        sum += p_current^(1 - fitness)
        grammar.log_probabilities[rule_index] *= 1 - fitness
    end
    total_sum = 0
    for rule_index in eachindex(grammar.rules)
        grammar.log_probabilities[rule_index] -= log2(sum)
        total_sum += exp2(grammar.log_probabilities[rule_index])
    end
    add_best_program!(grammar, PSols_with_eval_cache)
    @assert abs(total_sum - 1) <= 1e-4 "Total sum is $(total_sum) "
end

function update_grammar_4!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCacheTrace})
    sum = 0
    for rule_index in eachindex(grammar.rules)
        best_reward = 0
        for psol in PSols_with_eval_cache
            program = psol.program.children[end]
            if program.ind != 2
                program = program.children[end]
            end
            reward = psol.reward
            # check if the program tree has rule_index somewhere inside it using a recursive function
            if contains_rule(program, rule_index) && reward > best_reward
                best_reward = reward
            end
            if grammar.types[rule_index] == :DIR
                break
            end
        end

        if grammar.types[rule_index] == :DIR
            log_prob = best_reward > 0 ? -1.0 : -10.0
            sum += exp2(log_prob)
            grammar.log_probabilities[rule_index] = log_prob
        else
            fitness = min(best_reward / 100, 1)

            p_current = exp2(grammar.log_probabilities[rule_index])

            sum += p_current^(1 - fitness)
            grammar.log_probabilities[rule_index] *= 1 - fitness
        end
    end
    total_sum = 0
    for rule_index in eachindex(grammar.rules)
        grammar.log_probabilities[rule_index] -= log2(sum)
        total_sum += exp2(grammar.log_probabilities[rule_index])
    end
    add_best_program!(grammar, PSols_with_eval_cache)
    @assert abs(total_sum - 1) <= 1e-4 "Total sum is $(total_sum) "
end

function update_grammar_5!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCacheTrace})
    sum = 0
    for rule_index in eachindex(grammar.rules)
        best_reward = 0
        for psol in PSols_with_eval_cache
            program = psol.program.children[end]
            if program.ind != 2
                program = program.children[end]
            end
            reward = psol.reward
            # check if the program tree has rule_index somewhere inside it using a recursive function
            if contains_rule(program, rule_index) && reward > best_reward
                best_reward = reward
            end
            if grammar.types[rule_index] == :DIR
                break
            end
        end

        if grammar.types[rule_index] == :DIR
            log_prob = best_reward > 0 ? -1.0 : -10.0
            sum += exp2(log_prob)
            grammar.log_probabilities[rule_index] = log_prob
        elseif grammar.types[rule_index] == :TIMES
            sum += exp2(grammar.log_probabilities[rule_index])
        else
            fitness = min(best_reward / 100, 1)

            p_current = exp2(grammar.log_probabilities[rule_index])

            sum += p_current^(1 - fitness)
            grammar.log_probabilities[rule_index] *= 1 - fitness
        end
    end
    total_sum = 0
    for rule_index in eachindex(grammar.rules)
        grammar.log_probabilities[rule_index] -= log2(sum)
        total_sum += exp2(grammar.log_probabilities[rule_index])
    end
    add_best_program!(grammar, PSols_with_eval_cache)
    @assert abs(total_sum - 1) <= 1e-4 "Total sum is $(total_sum) "
end

function update_grammar_6!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCacheTrace})
    randomise_costs!(grammar)
    add_best_program!(grammar, PSols_with_eval_cache)
end

function add_best_program!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCacheTrace})
    expr = rulenode2expr(PSols_with_eval_cache[begin].program, grammar)
    grammar.rules[1] = :([$expr; ACT])
end

"""
    contains_rule(program::RuleNode, rule_index::Int)

Check if a given `program` contains a derivation rule with the specified `rule_index`.

# Arguments
- `program::RuleNode`: The `program` to check.
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

"""
    randomise_costs!(grammar::ContextSensitiveGrammar)

Randomise the costs of the rules in the `grammar`.
"""
function randomise_costs!(grammar::ContextSensitiveGrammar)
    sum = 0
    for rule_index in eachindex(grammar.rules)
        log_prob = Float64(-rand(1:3))
        grammar.log_probabilities[rule_index] = log_prob
        sum += exp2(log_prob)
    end
    total_sum = 0
    for rule_index in eachindex(grammar.rules)
        grammar.log_probabilities[rule_index] -= log2(sum)
        total_sum += exp2(grammar.log_probabilities[rule_index])
    end
    @assert abs(total_sum - 1) <= 1e-4 "Total sum is $(total_sum) "
end
