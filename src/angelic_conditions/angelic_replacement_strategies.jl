"""
    replace_first_angelic!(program::RuleNode, boolean_expr::RuleNode, angelic_rulenode::RuleNode, angelic_conditions::Dict{UInt16,UInt8})
        ::Union{Tuple{RuleNode,Int,AbstractHole},Nothing}

Replaces the first `AbstractHole` node in the `program` with the `boolean_expr` node. 
The 'first' is defined here as the first node visited by pre-order traversal, left-to-right. The program is modified in-place.

# Arguments
- `program`: The program to resolve angelic conditions in.
- `boolean_expr`: The boolean expression node to replace the `AbstractHole` node with.
- `angelic_rulenode`: The angelic rulenode. Used to compare against nodes in the program.
- `angelic_conditions`: A dictionary mapping indices of angelic condition candidates, to the child index that may be changed.

# Returns
The parent node, the index of its modified child, and the modification. Used to clear the changes if replacement is unsuccessful.

"""
function replace_first_angelic!(
    program::RuleNode,
    boolean_expr::RuleNode,
    angelic_rulenode::RuleNode,
    angelic_conditions::Dict{UInt16,UInt8}
)::Union{Tuple{RuleNode,Int,AbstractHole},Nothing}
    angelic_index = get(angelic_conditions, program.ind, -1)
    for (child_index, child) in enumerate(program.children)
        if child_index == angelic_index && child isa AbstractHole
            program.children[child_index] = boolean_expr
            return (program, child_index, child)
        else
            res = replace_first_angelic!(child, boolean_expr, angelic_rulenode, angelic_conditions)
            if res !== nothing
                return res
            end
        end
    end
    return nothing
end


"""
    replace_last_angelic!(program::RuleNode, boolean_expr::RuleNode, angelic_rulenode::RuleNode, angelic_conditions::Dict{UInt16,UInt8})
        ::Union{Tuple{RuleNode,Int,AbstractHole},Nothing}

Replaces the last `AbstractHole` node in the `program` with the `boolean_expr` node. 
The 'last' is defined here as the first node visited by reversed pre-order traversal (right-to-left). The program is modified in-place.

# Arguments
- `program`: The program to resolve angelic conditions in.
- `boolean_expr`: The boolean expression node to replace the `AbstractHole` node with.
- `angelic_rulenode`: The angelic rulenode. Used to compare against nodes in the program.
- `angelic_conditions`: A dictionary mapping indices of angelic condition candidates, to the child index that may be changed.

# Returns
The parent node, the index of its modified child, and the modification. Used to clear the changes if replacement is unsuccessful.

"""
function replace_last_angelic!(
    program::RuleNode,
    boolean_expr::RuleNode,
    angelic_rulenode::RuleNode,
    angelic_conditions::Dict{UInt16,UInt8}
)::Union{Tuple{RuleNode,Int,AbstractHole},Nothing}
    angelic_index = get(angelic_conditions, program.ind, -1)
    # Store indices to go over them backwards later
    indices = Vector{Int}([])
    for child_index in reverse(eachindex(program.children))
        child = program.children[child_index]
        if child_index == angelic_index && child isa AbstractHole
            program.children[child_index] = boolean_expr
            return (program, child_index, child)
        else
            push!(indices, child_index)
        end
    end
    # If no angelic in this layer, continue onto lower layers, in reverse
    for child_index in indices
        res = replace_last_angelic!(program.children[child_index], boolean_expr, angelic_rulenode, angelic_conditions)
        if res !== nothing
            return res
        end
    end
    return nothing
end