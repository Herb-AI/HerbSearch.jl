"""
    collect_subtrees(tree::AbstractRuleNode)

Returns a vector of all subtrees in the AST, including `tree` itself.
"""
function collect_subtrees(tree::AbstractRuleNode)
    subtrees = AbstractRuleNode[]
    stack=AbstractRuleNode[tree]

    while !isempty(stack)
        node = pop!(stack)
        push!(subtrees, node)

        for child in HerbCore.get_children(node)
            push!(stack, child)
        end

    end
    return subtrees
end

"""
    count_nonhole_nodes(t)

Count how many nodes in the AST `t` are *not* UniformHoles.
"""
function count_nonhole_nodes(t::AbstractRuleNode)
    sum(!(node isa UniformHole) for node in collect_subtrees(t))
end

"""
    count_holes(t)

Count how many UniformHole nodes appear in the AST `t`.
"""
function count_holes(t::AbstractRuleNode)
    sum(node isa UniformHole for node in collect_subtrees(t))
end

"""
    passes_hole_thresholds(t; min_nonholes=2, max_holes=3)

Return `true` if pattern `t` meets the required structural thresholds:

- `min_nonholes`: minimum number of non-hole nodes (ensures pattern is meaningful)
- `max_holes`: maximum number of hole nodes (prevents overly generic patterns)

Used for selecting which anti-unified patterns should be kept
during MST-style iterative generalization.
"""
function passes_hole_thresholds(t; min_nonholes=2, max_holes=3)
    count_nonhole_nodes(t) >= min_nonholes &&
    count_holes(t) <= max_holes
end