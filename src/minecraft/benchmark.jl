include("cl_args.jl")

args = parse_commandline()
experiment_number::Int = args["experiment"]
seed::Int = args["seed"]
number_of_tries::Int = args["tries"]
max_time::Int = args["max-time"]
env_name::String = args["env"]

include("minerl.jl")
include("logo_print.jl")

using HerbGrammar, HerbSpecification, HerbSearch
using HerbSearch: ProgramCacheTrace
using Logging, JSON
using Random
disable_logging(LogLevel(1))

Random.seed!(seed)

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

# make sure the probabilities are equal 
@assert all(prob -> prob == minerl_grammar.log_probabilities[begin], minerl_grammar.log_probabilities)

# override the evaluate trace function
HerbSearch.evaluate_trace(prog::RuleNode, grammar::ContextSensitiveGrammar) = evaluate_trace_minerl(prog, grammar, environment, show_moves=args["render"])
# override cost function
HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_prob(rule_index, grammar)

# create environment
if !(@isdefined environment)
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; seed=seed, inf_health=true, inf_food=true, disable_mobs=true)
end
print_logo()
printstyled("Running experiment $(experiment_number) with seed $seed.\n", color=:magenta, bold=true)

experiment_data = Dict{String,Any}()

experiment_data["experiment"] = Dict{String,Any}(
    "number" => experiment_number
)

experiment_data["world"] = Dict{String,Any}(
    "seed" => seed,
    "description" => world_descriptions[seed]
)


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

# set experiment parameters
cycle_length = 0
randomise_costs = false

if experiment_number == 1
    experiment_data["experiment"]["description"] = """
        Partial solution: reward > best_reward.
        Cycle length 6.
        Select 5 programs with highest reward.
        Update based on last action; fit = min(best_reward / 100, 1); replace start symbol with [best_program; ACT]."""

    cycle_length = 6
elseif experiment_number == 2
    experiment_data["experiment"]["description"] = """
        Partial solution: reward > best_reward.
        Cycle length 6.
        Select 5 programs with highest reward.
        Update based on last action; fit = min(best_reward / 100, 1); replace start symbol with [best_program; ACT].
        Allow taking multiple actions after best program."""

    cycle_length = 6
    minerl_grammar = @pcsgrammar begin
        1:SEQ = ACT
        2:ACT = [A] | [ACT; A]
        1:A = (TIMES, Dict("move" => DIR, "sprint" => 1, "jump" => 1))
        8:DIR = 0b0001 | 0b0010 | 0b0100 | 0b1000 | 0b0101 | 0b1001 | 0b0110 | 0b1010 # forward | back | left | right | forward-left | forward-right | back-left | back-right
        6:TIMES = 5 | 10 | 25 | 50 | 75 | 100
    end
elseif experiment_number == 3
    experiment_data["experiment"]["description"] = """
        Partial solution: reward > best_reward.
        Cycle length 8.
        Select 5 programs with highest reward.
        Update based on last action; fit = min(best_reward / 100, 1); replace start symbol with [best_program; ACT].
        Allow taking multiple actions after best program.
        Change (TIMES, action) to (action, TIMES)"""

    cycle_length = 8
    minerl_grammar = @pcsgrammar begin
        1:SEQ = ACT
        2:ACT = [A] | [ACT; A]
        1:A = (Dict("move" => DIR, "sprint" => 1, "jump" => 1), TIMES)
        8:DIR = 0b0001 | 0b0010 | 0b0100 | 0b1000 | 0b0101 | 0b1001 | 0b0110 | 0b1010 # forward | back | left | right | forward-left | forward-right | back-left | back-right
        6:TIMES = 5 | 10 | 25 | 50 | 75 | 100
    end
elseif experiment_number == 4
    experiment_data["experiment"]["description"] = """
        Partial solution: reward > best_reward.
        Cycle length 8.
        Select 5 programs with highest reward.
        Update based on last action; fit = min(best_reward / 100, 1); replace start symbol with [best_program; ACT].
        Allow taking multiple actions after best program.
        Change (TIMES, action) to (action, TIMES).
        Last direction higher probability, other directions lower uniform probability."""

    cycle_length = 8
    minerl_grammar = @pcsgrammar begin
        1:SEQ = ACT
        2:ACT = [A] | [ACT; A]
        1:A = (Dict("move" => DIR, "sprint" => 1, "jump" => 1), TIMES)
        8:DIR = 0b0001 | 0b0010 | 0b0100 | 0b1000 | 0b0101 | 0b1001 | 0b0110 | 0b1010 # forward | back | left | right | forward-left | forward-right | back-left | back-right
        6:TIMES = 5 | 10 | 25 | 50 | 75 | 100
    end
    HerbSearch.update_grammar!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCacheTrace}) = HerbSearch.update_grammar_4!(grammar, PSols_with_eval_cache)
elseif experiment_number == 5
    experiment_data["experiment"]["description"] = """
        Partial solution: reward > best_reward.
        Cycle length 8.
        Select 5 programs with highest reward.
        Update based on last action; fit = min(best_reward / 100, 1); replace start symbol with [best_program; ACT].
        Allow taking multiple actions after best program.
        Change (TIMES, action) to (action, TIMES).
        Last direction higher probability, other directions lower uniform probability.
        Uniform probabilities for TIMES."""

    cycle_length = 8
    minerl_grammar = @pcsgrammar begin
        1:SEQ = ACT
        2:ACT = [A] | [ACT; A]
        1:A = (Dict("move" => DIR, "sprint" => 1, "jump" => 1), TIMES)
        8:DIR = 0b0001 | 0b0010 | 0b0100 | 0b1000 | 0b0101 | 0b1001 | 0b0110 | 0b1010 # forward | back | left | right | forward-left | forward-right | back-left | back-right
        6:TIMES = 5 | 10 | 25 | 50 | 75 | 100
    end
    HerbSearch.update_grammar!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCacheTrace}) = HerbSearch.update_grammar_5!(grammar, PSols_with_eval_cache)
elseif experiment_number == 6
    experiment_data["experiment"]["description"] = """
        Partial solution: reward > best_reward.
        Cycle length 8.
        Select 5 programs with highest reward.
        Start with random probablities; do not update probabilites; replace start symbol with [best_program; ACT].
        Allow taking multiple actions after best program.
        Change (TIMES, action) to (action, TIMES)."""

    cycle_length = 8
    minerl_grammar = @pcsgrammar begin
        1:SEQ = ACT
        2:ACT = [A] | [ACT; A]
        1:A = (Dict("move" => DIR, "sprint" => 1, "jump" => 1), TIMES)
        8:DIR = 0b0001 | 0b0010 | 0b0100 | 0b1000 | 0b0101 | 0b1001 | 0b0110 | 0b1010 # forward | back | left | right | forward-left | forward-right | back-left | back-right
        6:TIMES = 5 | 10 | 25 | 50 | 75 | 100
    end
    randomise_costs = true
    HerbSearch.update_grammar!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCacheTrace}) = HerbSearch.add_best_program!(grammar, PSols_with_eval_cache)
end

experiment_data["experiment"]["grammar"] = grammar_to_list(minerl_grammar)

# run experiment
tries = []
experiment_data["tries"] = tries

time_sum = 0

for i in 1:number_of_tries
    printstyled("\n=============== TRY $i ===============\n\n", color=:cyan, bold=true)
    if randomise_costs
        HerbSearch.randomise_costs!(minerl_grammar)
    end
    grammar = deepcopy(minerl_grammar)
    global number_of_evals = 0
    start_time = time()
    iter = HerbSearch.GuidedSearchTraceIterator(grammar, :SEQ, start_time, max_time)
    program, best_reward_over_time = probe(Vector{Trace}(), iter, max_time=max_time, cycle_length=cycle_length)
    end_time = time()

    time_taken = end_time - start_time
    if !isnothing(program)
        global time_sum += time_taken
    end

    push!(tries, Dict(
        "number" => i,
        "programs_evaluated" => number_of_evals,
        "program" => isnothing(program) ? nothing : string(eval(rulenode2expr(program, grammar))),
        "best_reward_over_time" => join(best_reward_over_time, ""),
        "time" => isnothing(program) ? "TIMEOUT" : time_taken
    ))

    # probe timed out, no point in running again (unless using random costs)
    if isnothing(program)
        printstyled("\nTry $i timed out.\n", color=:red, bold=true)
        if !randomise_costs
            break
        end
    else
        printstyled("\nFinished try $i in $(time_taken) seconds.\n", color=:green, bold=true)
    end

    if i != number_of_tries
        println("Restarting environment...")
        reset_env(environment)
    end
end

experiment_data["avg_time"] = time_sum == 0 ? "TIMEOUT" : time_sum / number_of_tries

dir = "experiments/experiment_$(experiment_number)"
file_path = "$dir/$(experiment_number)_$seed.json"

println("\nWriting data to $(pwd())/$(file_path)...")

# create directories
mkpath(dir)

# write data to file
file = open(file_path, "w")
JSON.print(file, experiment_data, 4)
close(file)

println("Done.")
