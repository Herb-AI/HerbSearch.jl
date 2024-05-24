include("create_minerl_env.jl")
using HerbGrammar, HerbSpecification
using HerbSearch
using Logging
disable_logging(LogLevel(1))

minerl_grammar = @pcsgrammar begin
    1:action_name = "forward"
    1:action_name = "left"
    1:action_name = "right"
    1:action_name = "back"
    1:action_name = "jump"
    1:sequence_actions = [sequence_actions; action]
    1:sequence_actions = []
    1:action = (TIMES, Dict("camera" => [0, 0], action_name => 1))
    5:TIMES = 1 | 5 | 25 | 50 | 75 | 100
end

minerl_grammar_2 = @pcsgrammar begin
    1:SEQ = [ACT]
    8:DIR = 0b0001 | 0b0010 | 0b0100 | 0b1000 | 0b0101 | 0b1001 | 0b0110 | 0b1010 # forward | back | left | right | forward-left | forward-right | back-left | back-right
    1:ACT = (TIMES, Dict("move" => DIR, "sprint" => 1, "jump" => 1))
    6:TIMES = 5 | 10 | 25 | 50 | 75 | 100
end

function evaluate_trace_minerl(prog, grammar, env, show_moves)
    resetPosition()
    expr = rulenode2expr(prog, grammar)

    sequence_of_actions = eval(expr)

    sum_of_rewards = 0
    is_done = false
    obs = nothing
    for (times, action) ∈ sequence_of_actions
        new_action = env.action_space.noop()
        for (key, val) in action
            if key == "move"
                new_action["forward"] = val & 1
                new_action["back"] = val >> 1 & 1
                new_action["left"] = val >> 2 & 1
                new_action["right"] = val >> 3
            else
                new_action[key] = val
            end
        end

        for i in 1:times
            obs, reward, done, _ = env.step(new_action)
            if show_moves
                env.render()
            end

            sum_of_rewards += reward
            if done
                is_done = true
                printstyled("sum of rewards: $sum_of_rewards. Done\n", color=:green)
                break
            end
        end
        if is_done
            break
        end
    end
    println("Reward $sum_of_rewards")
    return get_xyz_from_env(obs), is_done, sum_of_rewards
end

# make sure the probabilities are equal 
@assert all(prob -> prob == minerl_grammar_2.log_probabilities[begin], minerl_grammar_2.log_probabilities)

function HerbSearch.set_env_position(x, y, z)
    println("Setting env position: ($x, $y, $z)")
    set_start_xyz(x, y, z)
end
#  overwrite the evaluate trace function
HerbSearch.evaluate_trace(prog::RuleNode, grammar::ContextSensitiveGrammar; show_moves=false) = evaluate_trace_minerl(prog, grammar, env, show_moves)
HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_prob(rule_index, grammar)

# resetEnv()
iter = HerbSearch.GuidedTraceSearchIterator(minerl_grammar_2, :SEQ)
program = @time probe(Vector{Trace}(), iter, 3000000, 6)
