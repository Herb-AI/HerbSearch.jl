"""
    NodeSnapshot

An immutable, serializable copy of an [`AbstractRuleNode`](@ref) at one moment in time.

The solver mutates its tree in place (and `StateHole` domains are backtrackable), so the
inspector cannot hold on to live nodes. Every time something interesting happens, the
current tree is frozen into a `NodeSnapshot`.

- `rule`: the rule index if the node is filled, `0` otherwise
- `domain`: the rule indices that are still possible for this node
- `ishole`: whether the live node was an `AbstractHole`
- `isuniform`: whether the live node was uniform (fixed shape)
- `children`: snapshots of the children
"""
struct NodeSnapshot
    rule::Int
    domain::Vector{Int}
    ishole::Bool
    isuniform::Bool
    children::Vector{NodeSnapshot}
end

"""
    take_snapshot(node::AbstractRuleNode)::NodeSnapshot

Freeze `node` (and its subtree) into a [`NodeSnapshot`](@ref).
Works for `RuleNode`s, `Hole`s, `UniformHole`s and `StateHole`s.
"""
# Children of a node. Non-uniform `Hole`s have no children at all, so `get_children` is not
# defined for them.
_children(node::AbstractRuleNode) = hasproperty(node, :children) ? node.children : ()

function take_snapshot(node::AbstractRuleNode)::NodeSnapshot
    children = NodeSnapshot[take_snapshot(c) for c ∈ _children(node)]
    if node isa AbstractHole
        domain = collect(findall(node.domain))
        rule = length(domain) == 1 ? domain[1] : 0
        return NodeSnapshot(rule, domain, true, isuniform(node), children)
    end
    rule = get_rule(node)
    return NodeSnapshot(rule, Int[rule], false, true, children)
end

take_snapshot(::Nothing) = nothing

"""
    NodeChange

A single difference between two [`NodeSnapshot`](@ref)s, located at `path`.

- `kind`: `:domain` (rules were removed/added), `:fill` (the node became filled) or
  `:shape` (the node was substituted by a node of a different shape)
"""
struct NodeChange
    path::Vector{Int}
    kind::Symbol
    removed::Vector{Int}
    added::Vector{Int}
end

"""
    diff_snapshots(before, after)::Vector{NodeChange}

Compare two tree snapshots and report every node whose domain or shape changed.
This is what tells us *what a propagation actually did*.
"""
function diff_snapshots(before::Union{NodeSnapshot,Nothing}, after::Union{NodeSnapshot,Nothing})
    changes = NodeChange[]
    (isnothing(before) || isnothing(after)) && return changes
    _diff!(changes, before, after, Int[])
    return changes
end

function _diff!(changes::Vector{NodeChange}, a::NodeSnapshot, b::NodeSnapshot, path::Vector{Int})
    if a.domain != b.domain
        removed = setdiff(a.domain, b.domain)
        added = setdiff(b.domain, a.domain)
        kind = (length(b.domain) == 1 && length(a.domain) > 1) ? :fill : :domain
        push!(changes, NodeChange(copy(path), kind, removed, added))
    end
    if length(a.children) != length(b.children)
        push!(changes, NodeChange(copy(path), :shape, Int[], Int[]))
        return
    end
    for i ∈ eachindex(a.children)
        push!(path, i)
        _diff!(changes, a.children[i], b.children[i], path)
        pop!(path)
    end
end
