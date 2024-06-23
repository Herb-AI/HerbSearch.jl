using Statistics

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
        log_prob = ((1 - fitnes) * log(2, p_uniform))
        grammar.log_probabilities[rule_index] = log_prob
    end
    total_sum = 0
    for rule_index in eachindex(grammar.rules)
        grammar.log_probabilities[rule_index] = grammar.log_probabilities[rule_index] - log(2, sum)
        total_sum += 2^(grammar.log_probabilities[rule_index])
    end
    @assert abs(total_sum - 1) <= 1e-4 "Total sum is $(total_sum) "
end

count = zeros(Int, 16)
best_rewards = zeros(Float64, 16)
experiment = 0
function update_grammar!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCacheTrace})
    sum = 0

    if experiment == 18  || experiment == 13
        reset_grammar_node_count()
    end
    # mean_reward = mean(p.reward for p in PSols_with_eval_cache)
    # Track the best reward for each rule
    for rule_index in eachindex(grammar.rules)
        # best_reward = 0
        for psol in PSols_with_eval_cache
            program = psol.program.children[begin]
            reward = psol.reward
            # check if the program tree has rule_index somewhere inside it using a recursive function
            # if contains_rule(program, rule_index) && reward > best_reward
            #     best_reward = reward
            # end
            contains_num = contains_rule(program, rule_index, grammar)
            # if contains_rule(program, rule_index)
            
            if contains_num > 0
                count[rule_index] += contains_num
                # count[rule_index] += 1
                if reward > best_rewards[rule_index]
                    best_rewards[rule_index] = reward
                end
            end
        end
    end
    # println(best_rewards)
    # println(count)
    for rule_index in eachindex(grammar.rules)
        best_reward = best_rewards[rule_index]
        appearances = count[rule_index]
        fitness = 0
        if (experiment == 11 || experiment == 1)
            fitness = (best_reward / 100)
        elseif (experiment == 13 || experiment == 3)
            fitness = 1 - exp(-((best_reward / 55)^3))
        elseif (experiment == 14 || experiment == 4)
            fitness = (best_reward / 100) * (log(1 + appearances))
        elseif (experiment == 15 || experiment == 5)
            fitness = 0
        elseif (experiment == 16 || experiment == 6)
            fitness = appearances > 0 ? 0.3 : 0
        elseif (experiment == 17 || experiment == 7)
            fitness = log(10, best_reward+1)/2
        elseif (experiment == 18 || experiment == 8)
            fitness = 1 - (best_reward/100)
        end
        # println("fitness = $(fitness)")

        fitness = min(fitness, 1)
        p_current = 2^(grammar.log_probabilities[rule_index])
        sum += p_current^(1 - fitness)
        log_prob = ((1 - fitness) * log(2, p_current))
        grammar.log_probabilities[rule_index] = log_prob
    end
    total_sum = 0
    for rule_index in eachindex(grammar.rules)
        grammar.log_probabilities[rule_index] = grammar.log_probabilities[rule_index] - log(2, sum)
        total_sum += 2^(grammar.log_probabilities[rule_index])
    end
    expr = rulenode2expr(PSols_with_eval_cache[begin].program, grammar)
    grammar.rules[1] = :([$expr; ACT])
    @assert abs(total_sum - 1) <= 1e-4 "Total sum is $(total_sum) "
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
function contains_rule(program::RuleNode, rule_index::Int, grammar::ContextSensitiveGrammar)
    sum = 0
    # for p in program
    if program.ind == rule_index # if the rule is good return true
        sum = 1
    end
    for child in program.children
        # println(child)
        sum += contains_rule(child, rule_index, grammar)  # if a child has that rule then return true
    end
    # end
    if sum>0 
        # println("count of rule: $(rule_index) is $(sum) for program \n $(rulenode2expr(program, grammar))")
    end
    return sum # if no child has that rule return false
end

function flatten_nested_vector(v::Vector{RuleNode}, result=[])
    for element in v
        if isa(element, AbstractVector)
            flatten_nested_vector(element, result)
        else
            push!(result, element)
        end
    end
    return result
end

function reset_grammar_node_count()
    global count 
    count = ones(Int, 16)
    global best_rewards 
    best_rewards = zeros(Float64, 16)
end

function update_experiment_number(e::Int)
    global experiment
    experiment = e
end
