using HerbSearch, HerbCore, HerbSpecification, HerbInterpret, HerbGrammar, JSON
using Base

function parse_subtrees_to_json(subtrees::Vector{Any}, tree::RuleNode, id::Int)
    modified_subtrees = []
    for i in 1:length(subtrees)
        str = string(subtrees[i])
        modified_string = replace(str, r"hole\[Bool\[[^\]]*\]\]" => "_")
        push!(modified_subtrees, modified_string)
    end
    result = Dict(
        "ast" => length(string(tree)) > 2 ? string(tree) : string(tree)[1],
        "subtrees" => modified_subtrees
    )

    json_string = JSON.json(result)
    dir_path = dirname(@__FILE__)    
    path = joinpath(dir_path, "inputs", "parser_input$(id).json")

    open(path, "w") do file
        write(file, json_string)
    end
end