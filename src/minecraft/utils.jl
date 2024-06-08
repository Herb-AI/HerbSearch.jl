@kwdef struct SpecificationConfiguration
    max_reward::Float64 = 74.0
    reward_percentages::Vector{Float64} = [0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
    require_done::Bool = false
end

"""
    create_spec(max_reward::Float64, percentages::Vector{Float64}, require_done::Bool, starting_position::Tuple{Float64, Float64, Float64})::Vector{IOExample}

Creates the test spec for FrAngel, with the given reward percentages and starting position.
"""
function create_spec(max_reward::Float64, percentages::Vector{Float64}, require_done::Bool, starting_position::Tuple{Float64,Float64,Float64})::Vector{IOExample}
    spec = Vector{IOExample}()
    for perc in percentages
        spec = push!(spec, IOExample(Dict{Symbol,Any}(:start_pos => starting_position), (perc * max_reward, false)))
    end
    if require_done
        spec = push!(spec, IOExample(Dict{Symbol,Any}(), (max_reward, true)))
    end
    spec
end

"""
    print_logo()

Prints a stylized ascii art of the word probe.
"""
function print_logo()
    printstyled(raw"""                           
     _____  ____    ____  ____    ____    ___  _     
    |     ||    \  /    ||    \  /    |  /  _]| |    
    |   __||  D  )|  o  ||  _  ||   __| /  [_ | |    
    |  |_  |    / |     ||  |  ||  |  ||    _]| |___ 
    |   _] |    \ |  _  ||  |  ||  |_ ||   [_ |     |
    |  |   |  .  \|  |  ||  |  ||     ||     ||     |
    |__|   |__|\_||__|__||__|__||___,_||_____||_____|
                                                      """, color=:magenta, bold=true)
    println()
    println(repeat("=", 80) * "\n")
end