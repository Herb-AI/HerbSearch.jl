using PyCall
pyimport("minerl")

gym = pyimport("gym")

# WARNING: !!! NEVER MOVE THIS. It should ALWAYS be after the `pyimport`. I spent hours debugging this !!!
using HerbGrammar
mutable struct Environment
    env::PyObject
    settings::Dict{Symbol,Integer}
    start_pos::Tuple{Float64,Float64,Float64}
end

"""
    create_env(name::String; <keyword arguments>)

Create environment.

# Arguments
- `seed::Int`: the world seed.
- `inf_health::Bool`: enable infinite health.
- `inf_food::Bool`: enable infinite food.
- `disable_mobs`: disable mobs.
"""
function create_env(name::String; kwargs...)
    environment = Environment(gym.make(name), Dict(kwargs), (0, 0, 0))
    reset_env(environment)
    return environment
end

"""
    close_env(environment::Environment)

Close `environment`.
"""
function close_env(environment::Environment)
    environment.env.close()
end

"""
    reset_env(environment::Environment) 

Hard reset `environment`.
"""
function reset_env(environment::Environment)
    env = environment.env
    settings = environment.settings

    # set seed
    if haskey(settings, :seed)
        env.seed(settings[:seed])
    end
    obs = env.reset()

    # set start position
    environment.start_pos = get_xyz_from_obs(obs)
    print(environment.start_pos) #TODO: remove/change print

    # weird bug fix
    action = env.action_space.noop()
    action["forward"] = 1
    env.step(action)

    # infinite health
    if get(settings, :inf_health, false)
        env.set_next_chat_message("/effect @a minecraft:instant_health 1000000 100 true")
        env.step(action)
    end

    # infinite food
    if get(settings, :inf_food, false)
        env.set_next_chat_message("/effect @a minecraft:saturation 1000000 255 true")
        env.step(action)
    end

    # disable mobs
    if get(settings, :disable_mobs, false)
        env.set_next_chat_message("/gamerule doMobSpawning false")
        env.step(action)
        env.set_next_chat_message("/kill @e[type=!player]")
        env.step(action)
    end

    printstyled("Environment created. x: $(environment.start_pos[1]), y: $(environment.start_pos[2]), z: $(environment.start_pos[3])\n", color=:green) #TODO: remove/change print
end

"""
    get_xyz_from_obs(obs)::Tuple{Float64, Float64, Float64}

Get player coordinates from `obs`.
"""
function get_xyz_from_obs(obs)::Tuple{Float64,Float64,Float64}
    return obs["xpos"][1], obs["ypos"][1], obs["zpos"][1]
end

"""
    soft_reset_env(environment::Environment)

Reset player position to `environment.start_pos`.
"""
function soft_reset_env(environment::Environment)
    env = environment.env
    action = env.action_space.noop()
    x_player_start, y_player_start, z_player_start = environment.start_pos
    env.set_next_chat_message("/tp @a $(x_player_start) $(y_player_start) $(z_player_start)")

    obs = env.step(action)[1]
    obsx, obsy, obsz = get_xyz_from_obs(obs)
    while obsx != x_player_start || obsy != y_player_start || obsz != z_player_start
        obs = env.step(action)[1]
        obsx, obsy, obsz = get_xyz_from_obs(obs)
    end
end

"""
    evaluate_trace_minerl(prog::AbstractRuleNode, grammar::ContextSensitiveGrammar, environment::Environment, show_moves::Bool)

Evaluate in MineRL `environment`.
"""
function evaluate_trace_minerl(prog::AbstractRuleNode, grammar::ContextSensitiveGrammar, environment::Environment, show_moves::Bool)
    soft_reset_env(environment)

    expr = rulenode2expr(prog, grammar)
    sequence_of_actions = eval(expr)

    sum_of_rewards = 0
    is_done = false
    obs = nothing
    env = environment.env
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
                printstyled("sum of rewards: $sum_of_rewards. Done\n", color=:green) #TODO: remove/change print
                break
            end
        end
        if is_done
            break
        end
    end
    println("Reward $sum_of_rewards") #TODO: remove/change print
    return get_xyz_from_obs(obs), is_done, sum_of_rewards
end
