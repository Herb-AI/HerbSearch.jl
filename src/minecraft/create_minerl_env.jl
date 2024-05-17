using PyCall
pyimport("minerl")

gym = pyimport("gym")

if !@isdefined env
    printstyled("Creating environment\n", color=:yellow)
    env = gym.make("MineRLNavigateDenseProgSynth-v0")
    obs = env.reset()
    x_player_start, y_player_start, z_player_start = obs["xpos"], obs["ypos"], obs["zpos"]
    printstyled("Environment created x: $x_player_start, y: $y_player_start, z: $z_player_start\n", color=:green)
else
    printstyled("Environment already created\n", color=:green)
end