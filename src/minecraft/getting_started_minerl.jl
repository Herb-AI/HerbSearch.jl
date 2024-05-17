include("create_minerl_env.jl")
using HerbGrammar, HerbSpecification
using HerbSearch
# you might get an error here. Just type using HerbSearch in the REPL and run the whole file again.

minerl_grammar = @pcsgrammar begin
    1:action_name = "forward" | "backward" | "jump" | "left" | "right"
    1:action = Dict("camera" => [0, 0], action_name => 1)
    1:sequence_actions = [action; sequence_actions]
    1:sequence_actions = []
end

function create_random_program()
    return rand(RuleNode, minerl_grammar, :sequence_actions)
end


function evaluate_trace_minerl(prog, grammar, env)
    expr = rulenode2expr(prog, grammar)
    println("expr", expr)

    is_done = false
    is_partial_sol = false

    sequence_of_actions = eval(expr)
    eval_observation = []
    final_reward = 0
    for saved_action ∈ sequence_of_actions
        new_action = env.action_space.noop()
        for key ∈ keys(saved_action)
            new_action[key] = saved_action[key]
        end
        obs, reward, done, _ = env.step(new_action)

        push!(eval_observation, reward)
        env.render()

        final_reward = reward

        if reward > 0.1
            is_partial_sol = true
        end
        if done
            is_done = true
            printstyled("done\n", color=:green)
            break
        end
    end
    return eval_observation, is_done, is_partial_sol, final_reward
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
    print("Running chat ", action["chat"])

    env.step(action)
    env.render()
end

function run_forward_and_random()
    while true
        if rand() < 0.8
            new_action = env.action_space.noop()
            new_action["forward"] = 1
            new_action["jump"] = 1
            new_action["spint"] = 1
            run_action(new_action)
        else
            prog = create_random_program()
            evaluate_trace_minerl(prog, minerl_grammar, env)
        end
    end

end

run_forward_and_random()

# overwrite the evaluate trace function
HerbSearch.evaluate_trace(prog::RuleNode, grammar::ContextSensitiveGrammar) = evaluate_trace_minerl(prog, grammar, env)
# iter = HerbSearch.GuidedTraceSearchIterator(minerl_grammar, :sequence_actions)
# program = probe(Vector{Trace{String}}(), iter, 40, 10)

# program = @time probe(examples, iter,  3600, 10000)

