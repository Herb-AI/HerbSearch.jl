function create_spec(max_reward::Float64, percentages::Vector{Float64}, require_done::Bool, starting_position::Tuple{Float64, Float64, Float64})::Vector{IOExample}
    spec = Vector{IOExample}()
    for perc in percentages
        spec = push!(spec, IOExample(Dict{Symbol, Any}(:start_pos => starting_position), (perc * max_reward, false)))
    end

    if require_done
        spec = push!(spec, IOExample(Dict{Symbol, Any}(), (max_reward, true)))
    end

    spec
end