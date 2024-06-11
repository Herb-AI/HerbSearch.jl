# Manual setting of parameters instead of command line
experiment_number = 4
env_seed = [958129, 95812, 11248956, 6354, 999999]
# env_seed = [6354]
number_of_tries = 3
max_time = 900

include("minerl.jl")
include("logo_print.jl")

using HerbGrammar, HerbSpecification, HerbSearch
using Logging, JSON
disable_logging(LogLevel(1))

world_descriptions = Dict(
    958129 => "Relatively flat. Some trees. Cave opening.",
    95812 => "Big hole between start and goal. Small hills. Trees.",
    11248956 => "Big cave forward. Reward increases when entering cave. Goal not in cave.",
    6354 => "Many trees. Small hill.",
    999999 => "Desert. No obstacles."
)

minerl_grammar = @pcsgrammar begin
    1:SEQ = [ACT]
    1:ACT = (TIMES, Dict("move" => DIR, "sprint" => 1, "jump" => 1))
    8:DIR = 0b0001 | 0b0010 | 0b0100 | 0b1000 | 0b0101 | 0b1001 | 0b0110 | 0b1010 # forward | back | left | right | forward-left | forward-right | back-left | back-right
    6:TIMES = 5 | 10 | 25 | 50 | 75 | 100
end

"""
    grammar_to_list(grammar::ContextSensitiveGrammar)
Convert `grammar` to a list of rules with costs.
The entries have the form: `cost : type => rule`.
"""
function grammar_to_list(grammar::ContextSensitiveGrammar)
    rules = []
    for i in 1:length(grammar.rules)
        type = grammar.types[i]
        rule = grammar.rules[i]
        cost = HerbSearch.calculate_rule_cost(i, grammar)
        push!(rules, "$cost : $type => $rule")
    end
    return rules
end


# make sure the probabilities are equal 
@assert all(prob -> prob == minerl_grammar.log_probabilities[begin], minerl_grammar.log_probabilities)

# override the evaluate trace function
# HerbSearch.evaluate_trace(prog::RuleNode, grammar::ContextSensitiveGrammar; show_moves=false) = evaluate_trace_minerl(prog, grammar, environment, show_moves)
# HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_prob(rule_index, grammar)
print_logo()

for seed in env_seed
    tries = []
    global time_sum = 0
    # create environment
    # if !(@isdefined environment)
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; seed=seed, inf_health=true, inf_food=true, disable_mobs=true)
    # end
    HerbSearch.evaluate_trace(prog::RuleNode, grammar::ContextSensitiveGrammar; show_moves=false) = evaluate_trace_minerl(prog, grammar, environment, show_moves)
    HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_prob(rule_index, grammar)

    experiment_data = Dict{String,Any}()
    experiment_data["experiment"] = Dict{String,Any}(
        "experiment number" => experiment_number
    )
    experiment_data["world"] = Dict{String,Any}(
        "seed" => seed,
        "description" => world_descriptions[seed]
    )

    # set experiment parameters
    cycle_length = 0

    if experiment_number == 1
        experiment_data["experiment"]["description"] = """
        Base case
            Partial solution: reward > best_reward
            Cycle length 6.
            Select 5 programs with highest reward.
            Update based on last action. 
            fit = min(best_reward / 100, 1)"""
        experiment_data["experiment"]["grammar"] = grammar_to_list(minerl_grammar)
        cycle_length = 6
    elseif experiment_number == 2        
        experiment_data["experiment"]["description"] = """
        Look at lower amount of partial solutions
        Partial solution: reward > best_reward
        Cycle length 4.
        Select 3 programs with highest reward.
        Update based on last action. 
        fit = min(best_reward / 100, 1)"""
        experiment_data["experiment"]["grammar"] = grammar_to_list(minerl_grammar)
        cycle_length = 4
    elseif experiment_number == 3
        experiment_data["experiment"]["description"] = """
        Use a different fitness algorithm
        Partial solution: reward > best_reward
        Cycle length 6.
        Select 5 programs with highest reward.
        Update based on last action. 
        fit = 1 - exp(-(1/mean_reward) * best_reward)"""
        experiment_data["experiment"]["grammar"] = grammar_to_list(minerl_grammar)
        cycle_length = 6
    elseif experiment_number == 4
        experiment_data["experiment"]["description"] = """
        Use a different fitness algorithm
        Partial solution: reward > best_reward
        Cycle length 6.
        Select 5 programs with highest reward.
        Update based on last action. 
        fit = min(1,(best_reward / 100) * (log(1 + appearances)))"""
        experiment_data["experiment"]["grammar"] = grammar_to_list(minerl_grammar)
        cycle_length = 6
    end

    # run experiment

    experiment_data["tries"] = tries
    println("Seed value: $(seed)")
    for i in 1:number_of_tries
        println("try number:  $(i)")
        if experiment_number == 4
            count = zeros(Int, length(minerl_grammar.rules))
            best_rewards = zeros(Float64, length(minerl_grammar.rules))
        end
        grammar = deepcopy(minerl_grammar)
        global number_of_evals = 0
        start_time = time()
        iter = HerbSearch.GuidedSearchTraceIterator(grammar, :SEQ, start_time, max_time)
        program, best_reward_over_time = @time probe(Vector{Trace}(), iter, max_time=max_time, cycle_length=cycle_length)
        end_time = time()

        time_taken = end_time - start_time
        if !isnothing(program)
            global time_sum += time_taken
        end

        push!(tries, Dict(
            "number" => i,
            "programs_evaluated" => number_of_evals,
            "program" => isnothing(program) ? "NOTHING-TIMEOUT" : string(eval(rulenode2expr(program, grammar))),
            "best_reward_over_time" => join(best_reward_over_time, ""),
            "time" => isnothing(program) ? "TIMEOUT" : time_taken
        ))

        # probe timed out, no point in running again
        if isnothing(program)
            break
        end

        if i <= number_of_tries
            reset_env(environment)
        end
    end


    experiment_data["avg_time"] = time_sum == 0 ? "TIMEOUT" : time_sum / number_of_tries

    # create directories
    mkpath("experiments/experiment_$(experiment_number)")

    # write data to file
    file = open("experiments/experiment_$(experiment_number)/$seed.json", "w")
    JSON.print(file, experiment_data, 4)
    close(file)
    close_env(environment)
end