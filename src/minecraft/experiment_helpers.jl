using Base.Filesystem

"""
    create_experiment_file(directory_path::String, experiment_name::String)

Creates a new experiment file in the given directory with the given name. If a file with the same name already exists, it will create a new file with an incremented index.
The experiment name should not contain the ".json" extension.
"""
function create_experiment_file(; directory_path::String, experiment_name::String)
    mkpath(directory_path)
    experiment_name = replace(experiment_name, ".json" => "")
    file_path = joinpath(directory_path, experiment_name * ".json")

    if isfile(file_path)
        printstyled("File $file_path already exists. Creating a new one with incremental index\n",color=:yellow)
        
        index = 1
        while isfile(file_path)
            index += 1
            file_name = "$experiment_name" * "_$index.json"
            file_path = joinpath(directory_path, file_name)
        end
        printstyled("Created experiment file at $file_path\n", color=:green)
    end
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


"""
    grammar_to_list(grammar::ContextSensitiveGrammar)

Converts a grammar to a list of strings that represent each rule. The cost of each rule is computed using calculate_rule_cost.
"""
function grammar_to_list(grammar::ContextSensitiveGrammar)
    rules = Vector{String}()
    for i in eachindex(grammar.rules)
        type = grammar.types[i]
        rule = grammar.rules[i]
        cost = HerbSearch.calculate_rule_cost(i, grammar)
        push!(rules, "rule_cost $cost : $type => $rule")
    end
    return rules
end