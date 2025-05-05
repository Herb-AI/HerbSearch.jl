"""
    generate_tree_from_compression(parent, d, compression_id, grammar)

Generates a tree ([`RuleNode`](@ref)) from a given compression.

# Arguments
- `parent::Int64`: the ID of the parent node
- `d::Dict`: the global dictionary (key: node_id, value: namedTuple(compressiond_id, parent_id, child_nr, type, [children]))
- `compression_id::Int64`: the ID of the compression
- `grammar::AbstractGrammar`: the grammar to use

# Returns
- `tree::RuleNode`: the resulting [`RuleNode`](@ref)
"""
function generate_tree_from_compression(parent, d, compression_id, grammar)
    parent_type = d[parent].type
    actual_children = grammar.childtypes[parent_type]
    
    children::Vector{AbstractRuleNode} = []
    current_child = 1

    for child in d[parent].children
        child_tree = generate_tree_from_compression(child, d, compression_id, grammar)
        child_nr = d[child].child_nr
        while current_child < child_nr + 1
            hole = Hole(get_domain(grammar, grammar.bytype[actual_children[current_child]]))
            push!(children, hole)
            current_child = current_child + 1
        end

        push!(children, child_tree)
        current_child = current_child + 1
    end

    # add remaining children; children that could be missing
    if current_child > 1
        current_child = current_child - 1
        while current_child < length(actual_children)
            hole = Hole(get_domain(grammar, grammar.bytype[actual_children[current_child]]))
            push!(children, hole)
            current_child = current_child + 1
        end
    end 

    # if there are only holes, make a vector of holes
    if length(d[parent].children) == 0 && length(actual_children) > 0
        for i in (1,length(actual_children))
            hole = Hole(get_domain(grammar, grammar.bytype[actual_children[i]]))
            push!(children, hole)
        end
    end

    tree = RuleNode(parent_type, children)
    return tree
end

"""
    generate_trees_from_compressions(global_dict, stats, grammar)

Generates Herb trees from a given dictionary of compressions.

# Arguments
- `global_dict::Dict`: the global dictionary (key: node_id, value: namedTuple(compressiond_id, parent_id, child_nr, type, [children]))
- `stats::Dict`: the statistics of the compressions (key: compression_id, value: namedTuple(size, occurrences))
- `grammar::AbstractGrammar`: the grammar to use

# Returns
- `tree_stats_dict::Dict`: a dictionary of Herb trees (key: RuleNode, value: namedTuple(size, occurrences))
"""
function generate_trees_from_compressions(global_dict, stats, grammar)
    tree_stats_dict = Dict{RuleNode, NamedTuple{(:size,:occurrences), <:Tuple{Int64,Int64}}}()

    res = []
    for (comp_id, values) in stats
        t = generate_tree_from_compression(comp_id, global_dict, comp_id, grammar)
        tree_stats_dict[t] = values
        push!(res, t)
    end
    
    return res
end