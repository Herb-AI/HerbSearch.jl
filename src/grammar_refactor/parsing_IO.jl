using DataStructures
using JSON

"""
    parse_number(start_index::Int, input::AbstractString)

A helper method that parses a number from the string `input` starting at `start_index`.

# Arguments
- `start_index::Int`: the index to start parsing from
- `input::AbstractString`: the input string

# Returns
Return a tuple (number, i) consisting of
- `number::AbstractString`: the parsed number
- `i::Int64`: the index of the last character parsed
"""
function parse_number(start_index::Int, input::AbstractString)::Tuple{AbstractString, Int}
    number = ""
    i = start_index
    while i <= length(input)
        char = input[i]
        if isdigit(char)
            number = number * char
        else
            break
        end
        i += 1
    end
    return number, i - 1
end

"""
    parse_tree(input::AbstractString, global_dict::Dict=nothing, start_index::Int=0)

Parses a tree from a string.

# Arguments
- `input::AbstractString`: the input string
- `global_dict::Dict`: the global dictionary
- `start_index::Int`: the index to start parsing from

# Returns
- `index::Int`: the index of the last node parsed
- `output::String`: the parsed tree
""" 
function parse_tree(input::AbstractString, global_dict::Union{Nothing, Dict}=nothing, start_index::Int=0)::Tuple{Int, AbstractString}
    nodes, edges, output = "","",""
    parent, index = start_index, start_index
    # parent_stack keeps track of the parent node
    # child_stack keeps track of the last child number of the last depth
    parent_stack, child_stack = Stack{Int64}(), Stack{Int64}() 
    # Initialize the root
    (num, i) = parse_number(1, input)
    if start_index != 0
        nodes = nodes * "comp_root($start_index)."
        nodes = nodes * "\ncomp_node($(start_index), $(num))."
        global_dict[start_index] = (comp_id = start_index, parent_id = -1, child_nr = -1, type = parse(Int64, string(num)), children = Vector{Int64}())
    else  
        nodes = nodes * "node($(start_index), $(num))."
    end

    # Iterate over the input string
    i = i + 1
    while i <= length(input) - 1
        char = input[i]
        if char == '{'
            push!(parent_stack, index)
            push!(child_stack, 0)
            parent = index
        elseif char == '}'
            pop!(parent_stack)
            parent = first(parent_stack)
            pop!(child_stack)
        elseif char == '_'
            child_nr = pop!(child_stack)
            index += 1
            push!(child_stack, child_nr + 1)
        elseif isdigit(char)
            number, i = parse_number(i, input)
            index += 1 # Nr of node / edge
            if start_index != 0
                nodes = nodes * "\ncomp_node($index, $number)."
            else
                nodes = nodes * "\nnode($index, $number)."
            end
            child_nr = pop!(child_stack)
            edges = edges * "\nedge($parent, $index, $child_nr)."
            if start_index != 0
                global_dict[index] = (comp_id = start_index, parent_id = parent, child_nr = child_nr, type = parse(Int64, string(number)), children = Vector{Int64}())
                append!(global_dict[parent].children, index)
            end
            
            push!(child_stack, child_nr + 1)
        end
        i += 1
    end
    if start_index != 0
        output = "%Compression tree nodes\n" * nodes * "\n%Compression tree edges:" * edges
    else 
        output = "%Maint AST\n%Nodes\n" * nodes * "\n%Edges:" * edges
    end
    return index + 1, output
end

"""
    parse_json(json_content::AbstractString)

Parses a JSON file and returns 

The schema used follows this scheme. Entries can either be nodes with a certain id and grammar rule, or edges between nodes.
`Node(id, grammar_rule)` e.g. `Node(1, 1)`
`Edge(parent, child, child_nr)` e.g. `Edge(1, 2, 5)`

# Arguments
- `json_path::AbstractString`: the path to the JSON file

# Result
- `(output, global_dict)::(String: the parsed string, Dict`: the global dictionary)
"""
function parse_json(json_content::AbstractString)
   global_dict = Dict{Int64, NamedTuple{(:comp_id,:parent_id, :child_nr, :type, :children), <:Tuple{Int,Int,Int,Int,Vector}}}()
    # Read in the JSON file
    json_parsed = JSON.parse(json_content)
    ast = json_parsed["ast"]
    subtrees = json_parsed["subtrees"]
    # Parse the JSON file
    index, output = parse_tree(ast)
    for (i, subtree) in enumerate(subtrees)
        index, temp_output = parse_tree(subtree, global_dict, index)
        output = output * ("\n\n%Subtree $i\n") * temp_output
    end
    return (output, global_dict)
end

"""
    parse_subtrees_to_json(subtrees::Vector{Any}, tree::RuleNode)

Parses a list of subtrees to JSON. Returns the JSON string.

# Arguments
- `subtrees::Vector{Any}`: the list of subtrees
- `tree::RuleNode`: the root tree the subtrees were extracted from
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

"""
    read_json(json_content::String)

Reads a JSON file and returns the parsed content.

# Arguments
- `json_file::String`: the path to the JSON file

# Returns
- `json_parsed::Dict`: the parsed JSON content
"""
function read_json(json_content)
    json_parsed = JSON.parse(json_content)
    witnesses = json_parsed["Call"][1]["Witnesses"]
    last_witness = witnesses[end]
    last_value = last_witness["Value"] #The best solution found
    return last_value
end
