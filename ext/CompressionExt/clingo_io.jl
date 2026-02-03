using DocStringExtensions
using JSON

"""
    $(TYPEDSIGNATURES)

Parses a list of programs into a Clingo format.
Returns Clingo encoding of the ASTs.
"""
function parse_programs(programs::Vector{RuleNode})::String
    result = ""
    node_index = 0

    for (program_index, program) in enumerate(programs)
        node_index += 1
        result *= "\n\n% Program $program_index"
        result *= "\nroot($node_index)."
        parsed_program, node_index = _parse_rulenode(program, node_index)
        result *= parsed_program
    end

    return result
end

"""
    $(TYPEDSIGNATURES)

Recursively parses AST into a clingo format. 
Returns the parsed AST and index of the last node in the model.
"""
function _parse_rulenode(rulenode::Union{AbstractRuleNode, AbstractUniformHole}, node_index::Int)::Tuple{String, Int}
    if rulenode isa Hole
        rule = -1
        return "", node_index
    else
        rule = get_rule(rulenode)
    end
    parent_node_index = node_index
    result = "\nnode($parent_node_index, $rule)."
    parsed_rulenode, node_index = _parse_rulenodes(rulenode.children, node_index)
    result *= parsed_rulenode

    return result, node_index
end

"""
    $(TYPEDSIGNATURES)

Recursively parses ASTs. Intended to be called on children of a rule.
"""
function _parse_rulenodes(rulenodes::Vector{AbstractRuleNode}, parent_node_index::Int)::Tuple{String, Int}
    child_node_index = parent_node_index
    result = ""

    for (child_index, child) in enumerate(rulenodes)
        child_node_index += 1
        result *= "\nedge($parent_node_index, $child_node_index, $child_index)."
        parsed_program, child_node_index = _parse_rulenode(child, child_node_index)
        result *= parsed_program
    end

    return result, child_node_index
end


#####################
# Postprocessing
#####################


"""
    $(TYPEDSIGNATURES)

Reads a JSON file and returns the parsed content.

# Arguments
- `json_file::String`: the path to the JSON file

# Returns
- `json_parsed::Dict`: the parsed JSON content
"""
function read_last_witness_from_json(json_content)
    json_parsed = JSON.parse(json_content)

    if !("Witnesses" in keys(json_parsed["Call"][1]))
        return (nothing,nothing,nothing)
    end
    optimal = json_parsed["Result"] == "OPTIMUM FOUND"

    witnesses = json_parsed["Call"][1]["Witnesses"]

    last_witness = witnesses[end]
    last_value = last_witness["Value"] #The best solution found
    last_cost = last_witness["Costs"]
    return optimal, last_cost, last_value
end



"""
    $(TYPEDSIGNATURES)

Structure for pasing compression trees given by the 
"""
struct TreeNode
    id::Int64
    children::Dict{Int64, TreeNode}
    # children::Vector{NamedTuple{(:pos, :child), Tuple{Int64, TreeNode}}} # tuple (position, child)
    # known_children::Set{Int64} # set of children that are not a hole

    function TreeNode(id::Int64,
         children::Dict{Int64, TreeNode} = Dict{Int64, TreeNode}())
        new(id, children)
    end
end

"""
    $(TYPEDSIGNATURES)

Parses string containing compression found by the model into trees.
# Arguments
- `compressed_rulenode`: vector containing strings in following format 
    - `comp_root(X)`
    - `comp_node(X, RULE)`
    - `comp_edge(FROM, TO, POS)`
    - `assign(COMP_NODE, AST_NODE)`
"""
function parse_compressed_subtrees(compressed_rulenode::Vector{String})
    roots = filter(s -> startswith(s, "comp_root("), compressed_rulenode)
    edges_str = filter(s -> startswith(s, "comp_edge("), compressed_rulenode)
    nodes = filter(s -> startswith(s, "comp_node("), compressed_rulenode)

    @assert nodes !== nothing
    @assert roots !== nothing
    @assert edges_str !== nothing
    
    node_to_rule = Dict{Int64, Int64}()
    trees = Vector{TreeNode}()
    seen_nodes = Dict{Int64, TreeNode}()
    
    # find all roots, add them as a last seen node of their id
    for root in roots
        m = match(r"\((\d+), ?(\d+)", root)
        id_rule::Vector{String} = [id for id in m.captures if !isnothing(id)]

        r_id, rule = parse(Int64, id_rule[1]), parse(Int64, id_rule[2])
        root = TreeNode(r_id)
        push!(trees, root)
        node_to_rule[r_id] = rule
        seen_nodes[r_id] = root
    end

    # build dictionary {node: rule)
    for node in nodes
        m = match(r"comp_node\((\d+), ?(\d+)", node)
        n_r::Vector{String} = [r for r in m.captures if !isnothing(r)]
        node_to_rule[parse(Int64, n_r[1])] = parse(Int64, n_r[2])
    end
    
    # collect all nodes and build the trees
    edges = Vector{Tuple{Int64, Int64, Int64}}()
    for edge in edges_str
        m = match(r"comp_edge\((\d+), ?(\d+), ?(\d+)", edge)
        s_d::Vector{String} = [s for s in m.captures if !isnothing(s)]
        from, to, pos = parse(Int64, s_d[1]), parse(Int64, s_d[2]), parse(Int64, s_d[3])
        push!(edges, (from, to, pos))
    end

    while !isempty(edges)
        edge = popfirst!(edges)
        (from, to, pos) = edge
        if !(from in keys(seen_nodes))
            push!(edges, edge)
            continue
        end
        to_node = TreeNode(to)
        seen_nodes[from].children[pos] = to_node
        seen_nodes[to] = to_node
    end
    return (trees, node_to_rule)
end

"""
    $(TYPEDSIGNATURES)

Constructs a list of rules from a set of compression trees.

# Arguments
- `grammar`: The original grammar.
- `compression_trees`: A vector of `TreeNode` objects representing the compressed subtrees.
- `node2rule`: A dictionary mapping node IDs to their corresponding rule in the grammar.

# Returns
- `Vector`: A vector of `RuleNode` objects, each representing a rule constructed from the compression trees.
"""
function construct_subtrees(grammar::AbstractGrammar, compression_trees::Vector{TreeNode}, node2rule::Dict{Int64, Int64})
    rules = []
    for tree in compression_trees
        new_node =  _construct_rule(tree, grammar, node2rule)
        push!(rules, new_node)
    end
    return rules
end


"""
    $(TYPEDSIGNATURES)

Helper function to recursively construct a list of rules from a set of conpression trees.
"""
function _construct_rule(comp_tree::TreeNode, grammar::AbstractGrammar, node2rule::Dict{Int64, Int64})
    rule_id = node2rule[comp_tree.id]
    child_types = grammar.childtypes[rule_id]
    children::Vector{AbstractRuleNode} = []
    for i in eachindex(child_types)
        if !(i in keys(comp_tree.children))
            # child is NOT in the compressed AST, make a hole
            hole = Hole(get_domain(grammar, grammar.bytype[child_types[i]]))
            push!(children, 
            hole)
        else
            # child is in the compressed AST, make a rule for the child
            push!(children, 
            _construct_rule(comp_tree.children[i], grammar, node2rule))
        end
    end 
    return RuleNode(rule_id, children)
end


"""
    $(TYPEDSIGNATURES)
    
# Arguments
- rule::RuleNode - rule in which nonbranching elements will be removed.
- grammar::AbstractGrammar - Grammar of the rule. Used to get types of rules used in the first argument.

If a rule has nonbranching elements (e.g. rule A that can only go to B that goes only to C), such sequences will be replaced with
A -> C. The first symbol of such sequence will be start, and last will be end. Holes are not replaced.
"""
function merge_nonbranching_elements(rule::RuleNode, grammar::AbstractGrammar)
    for i in eachindex(rule.children)
        if !(isa(rule.children[i], AbstractHole))
            rule.children[i] = _merge_rec(rule.children[i], grammar)
        end
    end
    return rule
end


function _merge_rec(rule::RuleNode, grammar::AbstractGrammar)
    if length(rule.children) == 1  && !(isa(grammar.rules[rule.ind], Expr))
        if (isa(rule.children[1], AbstractHole))
            return rule.children[1]
        else
            return _merge_rec(rule.children[1], grammar)
        end
    else
        return(merge_nonbranching_elements(rule, grammar))
    end
    return rule
end