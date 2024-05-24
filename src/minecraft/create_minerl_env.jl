using PyCall
pyimport("minerl")

gym = pyimport("gym")
# our_seed = 95812 <- hard env
# our_seed = 958122 
our_seed = 958129 # initial env

"""
    resetEnv() 
This function resets the enviornment with the global provided seed and saves the initial X,Y,Z positions.
"""
function resetEnv()
    env.seed(our_seed)
    obs = env.reset()
    global x_player_start, y_player_start, z_player_start = get_xyz_from_env(obs)
    print(x_player_start, y_player_start, z_player_start)

    action = env.action_space.noop()
    action["forward"] = 1

    # infinite health
    env.set_next_chat_message("/effect @a minecraft:instant_health 1000000 100 true")
    env.step(action)

    # infinite food
    env.set_next_chat_message("/effect @a minecraft:saturation 1000000 255 true")
    env.step(action)

    # disable mobs
    env.set_next_chat_message("/gamerule doMobSpawning false")
    env.step(action)
    env.set_next_chat_message("/kill @e[type=!player]")
    env.step(action)

    printstyled("Environment created. x: $x_player_start, y: $y_player_start, z: $z_player_start\n", color=:green)
end

function set_start_xyz(x, y, z)
    global x_player_start = x
    global y_player_start = y
    global z_player_start = z
    println("New x: $x_player_start y: $y_player_start z: $z_player_start pos")
end
function get_xyz_from_env(obs)
    return obs["xpos"][1], obs["ypos"][1], obs["zpos"][1]
end

function resetPosition()
    action = env.action_space.noop()
    env.set_next_chat_message("/tp @a $(x_player_start) $(y_player_start) $(z_player_start)")

    obs = env.step(action)[1]
    obsx, obsy, obsz = get_xyz_from_env(obs)
    while obsx != x_player_start || obsy != y_player_start || obsz != z_player_start
        obs = env.step(action)[1]
        obsx, obsy, obsz = get_xyz_from_env(obs)
    end
    println((obsx, obsy, obsz))
end

if !@isdefined env
    printstyled("Creating environment\n", color=:yellow)
    env = gym.make("MineRLNavigateDenseProgSynth-v0")
    resetEnv()
    printstyled("Environment created. x: $x_player_start, y: $y_player_start, z: $z_player_start\n", color=:green)
else
    printstyled("Environment already created\n", color=:green)
end