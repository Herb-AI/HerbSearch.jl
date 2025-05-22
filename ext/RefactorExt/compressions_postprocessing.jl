"""
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
    parse_compressed_subtrees(compressed_rulenode::Vector{String})

Parses string containing compression found by the model into trees.
# Arguments
- `compressed_rulenode::Vector{String}`: vector containing strings in format 
"comp_root(X)", "comp_node(X, RULE)", "comp_edge(FROM, TO, POS)" and "assign(COMP_NODE, AST_NODE)"
"""
function parse_compressed_subtrees(compressed_rulenode::Vector{String}, old_model::Bool = false)
    roots = filter(s -> startswith(s, "comp_root("), compressed_rulenode)
    edeges_str = filter(s -> startswith(s, "comp_edge("), compressed_rulenode)
    nodes = filter(s -> startswith(s, "comp_node("), compressed_rulenode)
    assignments_str = filter(s -> startswith(s, "assign("), compressed_rulenode)
    
    node_to_rule = Dict{Int64, Int64}()
    trees = Vector{TreeNode}()
    seen_nodes = Dict{Int64, TreeNode}()
    
    # find all roots, add them as a last seen node of their id
    if old_model
        for root in roots
            r_id = parse(Int64, match(r"(\d+)", root)[1])
            root = TreeNode(r_id)
            push!(trees, root)
            seen_nodes[r_id] = root 
        end
    else
        for root in roots
            id_rule  = match(r"\((\d+), ?(\d+)", root)
            r_id, rule = parse(Int64, id_rule[1]), parse(Int64, id_rule[2])
            root = TreeNode(r_id)
            push!(trees, root)
            node_to_rule[r_id] = rule
            seen_nodes[r_id] = root 
        end
    end

    # build dictionary node to rule
    for node in nodes
        n_r = match(r"comp_node\((\d+), ?(\d+)", node)
        node_to_rule[parse(Int64, n_r[1])] = parse(Int64, n_r[2])
    end
    
    # collect all nodes and build the trees
    edges = Vector{Tuple{Int64, Int64, Int64}}()
    for edge in edeges_str
        s_d = match(r"comp_edge\((\d+), ?(\d+), ?(\d+)", edge)
        from, to, pos = parse(Int64, s_d[1]), parse(Int64 ,s_d[2]), parse(Int64, s_d[3])
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
    construct_subtrees(grammar::AbstractGrammar, 
    compression_trees::Vector{TreeNode}, 
    node2rule::Dict{Int64, Int64})::Vector{RuleNode}

Constructs a list of rules from a set of compression trees.

# Arguments
- `grammar::AbstractGrammar`: The original grammar.
- `compression_trees::Vector{TreeNode}`: A vector of `TreeNode` objects representing the compressed subtrees.
- `node2rule::Dict{Int64, Int64}`: A dictionary mapping node IDs to their corresponding rule in the grammar.

# Returns
- `Vector{RuleNode}`: A vector of `RuleNode` objects, each representing a rule constructed from the compression trees.
"""
function construct_subtrees(grammar::AbstractGrammar, compression_trees::Vector{TreeNode}, node2rule::Dict{Int64, Int64})
    rules = []
    for tree in compression_trees
        new_node =  _construct_rule(tree, grammar, node2rule)
        push!(rules, new_node)
    end
    return rules
end


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
# Arguments
- rule::RuleNode - rule in which nonbranching elements will be removed.
- grammar::AbstractGrammar - Grammar of the rule. Used to get types of rules used in the first argument.

# Description
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

# function lift_holes(rule::RuleNode, grammar::AbstractGrammar)
#     for i in  eachindex(rule.children)
#         c = rule.children[i]
#         if isa(c, AbstractHole) # && !isfilled(c)
#             new_hole = _lift_hole(c, grammar)
#             rule.children[i] = new_hole
#         else
#             lift_holes(c, grammar)
#         end
#     end
# end

# function _lift_hole(hole::AbstractHole, grammar::AbstractGrammar)
#     if isfilled(hole)
#         return hole
#     end
#     type = get_hole_type(hole, grammar)

#     new_hole = Hole(get_domain(grammar, grammar.bytype[type]))
#     return new_hole

# end


# function get_hole_type(hole::AbstractHole, grammar::AbstractGrammar)
#     @assert !isfilled(hole) "Hole $(hole) is convertable to an expression. There is no need to represent it using a symbol."
#     index = findfirst(hole.domain)
#     return isnothing(index) ? :Nothing : grammar.types[index]
# end