using HerbGrammar, HerbSpecification, HerbSearch
using Logging
disable_logging(LogLevel(1))


SEED = 958129

minerl_grammar = @pcsgrammar begin
    1:SEQ = [ACT]
    8:DIR = 0b0001 | 0b0010 | 0b0100 | 0b1000 | 0b0101 | 0b1001 | 0b0110 | 0b1010 # forward | back | left | right | forward-left | forward-right | back-left | back-right
    1:ACT = (TIMES, Dict("move" => DIR, "sprint" => 1, "jump" => 1))
    6:TIMES = 5 | 10 | 25 | 50 | 75 | 100
end

# make sure the probabilities are equal 
@assert all(prob -> prob == minerl_grammar.log_probabilities[begin], minerl_grammar.log_probabilities)

#  overwrite the evaluate trace function
HerbSearch.evaluate_trace(prog::RuleNode, grammar::ContextSensitiveGrammar; show_moves=false) = evaluate_trace_minerl(prog, grammar, show_moves)
HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_prob(rule_index, grammar)

create_env("MineRLNavigateDenseProgSynth-v0"; seed=SEED, inf_health=true, inf_food=true, disable_mobs=true)
iter = HerbSearch.GuidedSearchTraceIterator(minerl_grammar, :SEQ)
program = @time probe(Vector{Trace}(), iter, 3000000, 6)
