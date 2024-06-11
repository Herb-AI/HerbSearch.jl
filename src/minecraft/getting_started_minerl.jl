include("minerl.jl")
include("logo_print.jl")

using HerbGrammar, HerbSpecification, HerbSearch
using Logging
using Statistics
disable_logging(LogLevel(1))
# Statistics = "b8865327-98d6-58c5-9785-274930b6b1a9"


minerl_grammar = @pcsgrammar begin
    1:SEQ = [ACT]
    8:DIR = 0b0001 | 0b0010 | 0b0100 | 0b1000 | 0b0101 | 0b1001 | 0b0110 | 0b1010 # forward | back | left | right | forward-left | forward-right | back-left | back-right
    1:ACT = (TIMES, Dict("move" => DIR, "sprint" => 1, "jump" => 1))
    6:TIMES = 5 | 10 | 25 | 50 | 75 | 100
end

# make sure the probabilities are equal 
@assert all(prob -> prob == minerl_grammar.log_probabilities[begin], minerl_grammar.log_probabilities)

#  overwrite the evaluate trace function
HerbSearch.evaluate_trace(prog::RuleNode, grammar::ContextSensitiveGrammar; show_moves=true) = evaluate_trace_minerl(prog, grammar, environment, show_moves)
HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_prob(rule_index, grammar)
# count = ones(Int, length(minerl_grammar.rules))
# best_rewards = zeros(Float64, length(minerl_grammar.rules))
SEED = 958129
if !(@isdefined environment)
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; seed=SEED, inf_health=true, inf_food=true, disable_mobs=true)
end
print_logo()
iter = HerbSearch.GuidedSearchTraceIterator(minerl_grammar, :SEQ, time(), 1200)
program, best_reward_over_time  = @time probe(Vector{Trace}(), iter, max_time=3000000, cycle_length=6)
 