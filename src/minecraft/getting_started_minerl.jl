include("create_minerl_env.jl")
using HerbGrammar, HerbSpecification
using HerbSearch

os = pyimport("os")
os.environ["LANG"] = "en_US.UTF-8"
# you might get an error here. Just type using HerbSearch in the REPL and run the whole file again.

# minerl_grammar = @pcsgrammar begin
#     10:action_name = "forward" | "left" | "right"
#     1:action_name =  "jump" 
#     1:action = Dict("camera" => [0, 0], action_name => 1)
#     1:sequence_actions = [sequence_actions; action]
#     1:sequence_actions = []
# end

minerl_grammar_2 = @pcsgrammar begin
    100:F = 1
    1:F = 0
    1:L = 1
    100:L = 0
    1:R = 0
    100:R = 1
    100:J = 0
    1:J = 1
    100:B = 1
    1:B = 0
    10:sequence_actions = [sequence_actions; action]
    1:sequence_actions = []
    10:action= (TIMES, Dict("camera" => [0, 0], "forward" => F, "left" => L, "right" => R, "jump" => J, "back" => B))
    1:TIMES = 25 | 50 | 75 | 100 | 125 | 150 
end

function create_random_program()
    return rand(RuleNode, minerl_grammar, :sequence_actions)
end

iterations = 0
best_reward = 0
function evaluate_trace_minerl(prog, grammar, env)
    resetPosition()
    expr = rulenode2expr(prog, grammar)
    # println("expr is: ", expr)


    is_done = false
    is_partial_sol = false

    sequence_of_actions = eval(expr)
    if isempty(sequence_of_actions)
        return (0, 0, 0), false, false, 0
    end

    sum_of_rewards = 0
    obs = nothing
    for saved_action ∈ sequence_of_actions
        times, action = saved_action
        
        new_action = env.action_space.noop()
        for key ∈ keys(action)
            new_action[key] = action[key]
        end
        
        for i in 1:times
            obs, reward, done, _ = env.step(new_action)
            env.render()

            sum_of_rewards += reward

            if reward > 0
                is_partial_sol = true
            end
            if done
                println("Rewards ", sum_of_rewards)
                is_done = true
                printstyled("done\n", color=:green)
                break
            end
        end
    end
    println("Got reward: ", sum_of_rewards)
    global best_reward = max(best_reward, sum_of_rewards)
    printstyled("Best reward: $best_reward\n",color=:red)

    eval_observation = (round(obs["xpos"][1], digits=1), round(obs["ypos"][1], digits=1), round(obs["zpos"][1], digits=1))
    println(eval_observation)
    return eval_observation, is_done, is_partial_sol, sum_of_rewards
end

function run_action(action)
    obs, reward, done, _ = env.step(action)
    env.render()
    println("reward: $reward")
end

function resetEnv()
    obs = env.reset()
    x_player_start, y_player_start, z_player_start = obs["xpos"], obs["ypos"], obs["zpos"]
    printstyled("Environment reset x: $x_player_start, y: $y_player_start, z: $z_player_start\n", color=:green)
end


function resetPosition()
    action = env.action_space.noop()
    action["chat"] = "/tp @a $(x_player_start[1]) $(y_player_start[1]) $(z_player_start[1])"
    # print("Running chat ", action["chat"])

    env.step(action)
    env.render()
end

function run_forward_and_random()
    while true
        if rand() < 0.8
            new_action = env.action_space.noop()
            new_action["forward"] = 1
            # new_action["jump"] = 1
            new_action["spint"] = 1
            run_action(new_action)
        else
            prog = create_random_program()
            evaluate_trace_minerl(prog, minerl_grammar_2, env)
        end
    end

end

# run_forward_and_random()

# # # overwrite the evaluate trace function
HerbSearch.evaluate_trace(prog::RuleNode, grammar::ContextSensitiveGrammar) = evaluate_trace_minerl(prog, grammar, env)
HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_prob(rule_index, grammar)
iter = HerbSearch.GuidedTraceSearchIterator(minerl_grammar_2, :sequence_actions)
program = probe(Vector{Trace}(), iter, 400000, 100000)


# state = nothing
# next = iterate(iter)
# print(next)
# while next !== nothing
#     prog, state = next
#     if (state.level > 100)
#         break
#     end
#     global next = iterate(iter, state)
# end

