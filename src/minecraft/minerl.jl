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
end

"""
    get_xyz_from_obs(obs)::Tuple{Float64, Float64, Float64}

Get player coordinates from `obs`.
"""
function get_xyz_from_obs(obs)::Tuple{Float64,Float64,Float64}
    return obs["xpos"][1], obs["ypos"][1], obs["zpos"][1]
end

"""
    soft_reset_env(environment::Environment, start_pos::Tuple{Float64, Float64, Float64})

Reset player position to `start_pos`.
"""
function soft_reset_env(environment::Environment, start_pos::Tuple{Float64, Float64, Float64})
    env = environment.env
    action = env.action_space.noop()
    x_player_start, y_player_start, z_player_start = start_pos
    env.set_next_chat_message("/tp @a $(x_player_start) $(y_player_start) $(z_player_start)")

    obs = env.step(action)[1]
    obsx, obsy, obsz = get_xyz_from_obs(obs)
    start_time = time()
    while obsx != x_player_start || obsy != y_player_start || obsz != z_player_start
        obs = env.step(action)[1]
        obsx, obsy, obsz = get_xyz_from_obs(obs)
        if time() - start_time > 5
            println("Can't reset properly to position $(start_pos)")
            break
        end
    end
end


"""
    The state of a program in the Minecraft environment.
"""
@kwdef mutable struct ProgramState
    current_position::Tuple{Float64, Float64, Float64} = (0.0, 0.0, 0.0)
    last_position::Tuple{Float64, Float64, Float64} = (0.0, 0.0, 0.0)
    is_done::Bool = false
    total_reward::Float64 = 0.0
    last_reward::Float64 = 0.0
end

"""
    test_reward_output_tuple(exec_output::ProgramState, expected_out::Tuple{Float64, Bool})::Bool

Test if the output of the program passes the expected output. 
If the program is done, it should return true. If the program is not done, it should return false if the expected output is done. 
Otherwise, it should return true if the total reward of the program is equal to or bigger than the expected total reward.

# Arguments
- `exec_output::ProgramState`: The output of the program
- `expected_out::Tuple{Float64, Bool}`: The expected output of the program. (total_reward, is_done)

# Returns
- Whether the output of the program passes the expected output.
"""
function test_reward_output_tuple(exec_output::ProgramState, expected_out::Tuple{Float64, Bool})::Bool
    if exec_output.is_done
        return true
    elseif expected_out[2]
        return false
    else
        return expected_out[1] <= exec_output.total_reward
    end
end

"""
    update_state!(state::ProgramState, obs, reward, done)

Update the state of the program based on the observation, reward, and done flag.

# Arguments
- `state::ProgramState`: The current state of the program.
- `obs`: The observation from the environment.
- `reward`: The reward from the environment.
- `done`: Whether the episode is done.
"""
function update_state!(state::ProgramState, obs, reward, done)
    state.last_position = state.current_position
    state.current_position = get_xyz_from_obs(obs)
    state.last_reward = state.total_reward
    state.total_reward += reward
    state.is_done = done
end

"""
    mc_init(start_pos::Tuple{Float64, Float64, Float64})::ProgramState

Initializes the Minecraft environment and returns the initial state.

# Arguments
- `start_pos::Tuple{Float64, Float64, Float64}`: The starting position of the player.

# Returns
- The initial state of the program.
"""
function mc_init(start_pos::Tuple{Float64, Float64, Float64})::ProgramState
    soft_reset_env(environment, start_pos)
    if RENDER
        environment.env.render()
    end 
    action = environment.env.action_space.noop()
    obs, _, done, _ = environment.env.step(action)

    return ProgramState(
        total_reward = 0.0,
        last_reward = 0.0,
        is_done = done,
        current_position = get_xyz_from_obs(obs),
        last_position = get_xyz_from_obs(obs))
end

"""
    mc_move!(state::ProgramState, directions, times::UInt = 1, sprint::UInt = 0, jump::UInt = 0, sneak::UInt = 0)

Move the player in the Minecraft environment.

# Arguments
- `state::ProgramState`: The current state of the program.
- `directions::Vector{String}`: The directions to move the player. Possible values are "forward", "back", "left", and "right".
- `times::UInt = 1`: The number of times to move the player.
- `sprint::UInt = 0`: Whether to sprint while moving.
- `jump::UInt = 0`: Whether to jump while moving.
- `sneak::UInt = 0`: Whether to sneak while moving.
"""
function mc_move!(program_state::ProgramState, directions, times::Int = 1, sprint::Int = 1, jump::Int = 1, sneak::Int = 0)
    if program_state.total_reward < -10 # TODO: Configure
        return
    end

    # set action
    action = environment.env.action_space.noop()
    for direction in directions
       action[direction] = 1
    end
    action["sprint"] = sprint   
    action["jump"] = jump
    action["sneak"] = sneak

    # execute action and update state accordingly
    for i in 1:times
        obs, reward, done, _ = environment.env.step(action)
        update_state!(program_state, obs, reward, done)

        if RENDER
            environment.env.render()
        end
    end
end

"""
    mc_end(state::ProgramState)::ProgramState

End the program and return the final state.

# Arguments
- `state::ProgramState`: The current state of the program.

# Returns
- The final state of the program.
"""
function mc_end(program_state::ProgramState)::ProgramState
    # if state.total_reward > 0
    #     println(state)
    # end
    program_state
end

"""
    mc_was_good_move(state::ProgramState)::Bool

Check if the last move reward was positive.

# Arguments
- `state::ProgramState`: The current state of the program.

# Returns
- Whether the last move reward was positive.
"""
function mc_was_good_move(program_state::ProgramState)::Bool
    return program_state.total_reward > program_state.last_reward
end

"""
    mc_has_moved(state::ProgramState)::Bool

Check if the player has moved.

# Arguments
- `state::ProgramState`: The current state of the program.

# Returns
- Whether the player has moved.
"""
function mc_has_moved(program_state::ProgramState)::Bool
    return program_state.current_position != program_state.last_position
end

"""
    is_done(progarm_state::ProgramState)::Bool

Check if the program is done.

# Arguments
- `progarm_state::ProgramState`: The current state of the program.

# Returns
- Whether the program is done.
"""
function is_done(progarm_state::ProgramState)::Bool
    return progarm_state.is_done
end