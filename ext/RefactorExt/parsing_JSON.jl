using JSON

function parse_programs(programs::Vector{RuleNode})::String
    result = ""
    node_index = 0

    for (program_index, program) in enumerate(programs)
        node_index += 1
        result *= "\n\n% Program $program_index"
        result *= "\nroot($node_index)."
        parsed_program, node_index = parse_rulenode(program, node_index)
        result *= parsed_program
    end

    return result
end

function parse_rulenode(rulenode::Union{AbstractRuleNode, AbstractUniformHole}, node_index::Int)::Tuple{String, Int}
    rule = get_rule(rulenode)
    parent_node_index = node_index
    result = "\nnode($parent_node_index, $rule)."
    parsed_rulenode, node_index = parse_rulenodes(rulenode.children, node_index)
    result *= parsed_rulenode

    return result, node_index
end

function parse_rulenodes(rulenodes::Vector{AbstractRuleNode}, parent_node_index::Int)::Tuple{String, Int}
    child_node_index = parent_node_index
    result = ""

    for (child_index, child) in enumerate(rulenodes)
        child_node_index += 1
        result *= "\nedge($parent_node_index, $child_node_index, $child_index)."
        parsed_program, child_node_index = parse_rulenode(child, child_node_index)
        result *= parsed_program
    end

    return result, child_node_index
end

"""
    read_last_witness_from_json(json_content::String)

Reads a JSON file and returns the parsed content.

# Arguments
- `json_file::String`: the path to the JSON file

# Returns
- `json_parsed::Dict`: the parsed JSON content
"""
function read_last_witness_from_json(json_content)
    json_parsed = JSON.parse(json_content)
    witnesses = json_parsed["Call"][1]["Witnesses"]
    last_witness = witnesses[end]
    last_value = last_witness["Value"] #The best solution found
    return last_value
end
