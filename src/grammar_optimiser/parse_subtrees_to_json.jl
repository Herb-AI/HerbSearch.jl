using HerbCore, HerbSpecification, HerbInterpret, HerbGrammar, JSON
using Base

"""
    parse_subtrees_to_json(subtrees::Vector{Any}, tree::RuleNode)

Parses a list of subtrees to a JSON string.
# Arguments
- `subtrees::Vector{Any}`: the list of subtrees
- `tree::RuleNode`: the root tree the subtrees were extracted from
# Result
- `json_string::String`: the JSON string
"""
function parse_subtrees_to_json(subtrees::Vector{Any}, tree::RuleNode)
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
    
    return json_string
end