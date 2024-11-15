"""
    generate_tree_from_compression(parent, d, compression_id, grammar)

Generates a Herb tree from a given compression.
# Arguments
- `parent::Int64`: the ID of the parent node
- `d::Dict`: the global dictionary (key: node_id, value: namedTuple(compressiond_id, parent_id, child_nr, type, [children]))
- `compression_id::Int64`: the ID of the compression
- `grammar::AbstractGrammar`: the grammar to use
# Result
- `tree::RuleNode`: the Herb tree
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
- `stats::Dict`: the statistics of the compressions (key: compression_id, value: namedTuple(size, occurences))
- `grammar::AbstractGrammar`: the grammar to use
# Result
- `tree_stats_dict::Dict`: a dictionary of Herb trees (key: RuleNode, value: namedTuple(size, occurences))
"""
function generate_trees_from_compressions(global_dict, stats, grammar)
    tree_stats_dict = Dict{RuleNode, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}()

    for (comp_id, values) in stats
        t = generate_tree_from_compression(comp_id, global_dict, comp_id, grammar)
        tree_stats_dict[t] = values
    end
    
    return tree_stats_dict
end


"""
    extend_grammar(tree, grammar)
Extends a given grammar with a Herb tree.
# Arguments
- `tree::RuleNode`: the Herb tree
- `grammar::AbstractGrammar`: the grammar to extend
# Result
- `grammar::AbstractGrammar`: the extended grammar
"""
function extend_grammar(tree, grammar)
    type = return_type(grammar, tree.ind)
    new_grammar_rule = rulenode2expr(tree, grammar)
    add_rule!(grammar, :($type = $new_grammar_rule))

    return grammar
end