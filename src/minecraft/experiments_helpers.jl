include("../probe/grammar_helpers.jl")
include("../probe/logo_print.jl")

using Base.Filesystem

function create_experiment_file(; directory_path::String, experiment_name::String)
    mkpath(directory_path)
    experiment_name = replace(experiment_name, ".json" => "")
    file_path = joinpath(directory_path, experiment_name * ".json")

    # Create the file if it does not exist
    index = 1
    while isfile(file_path)
        index += 1
        file_name = "$experiment_name" * "_$index.json"
        file_path = joinpath(directory_path, file_name)
        println(file_path)
    end

    printstyled("Created experiment file at $file_path\n", color=:green)
    open(file_path, "w") do f
        write(f, "")
    end
    return file_path
end


function append_to_json_file(filepath, new_data)
    open(filepath, "r") do file
        json_data = JSON.parse(read(file, String))
        json_data = [json_data; new_data]
        open(filepath, "w") do f
            write(f, json(json_data, 4))
        end
    end
end

function build_final_experiment_json(experiment_name::String, world_json::Dict, probe_configuration::Dict, tries_data::Vector)
    return Dict(
        :experiment_name => experiment_name,
        :minecraft_world => world_json,
        :probe_configuration => probe_configuration,
        :tries_data => tries_data
    )
end