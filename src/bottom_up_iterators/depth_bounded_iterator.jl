Base.@doc """
    @programiterator DepthBoundedIterator{T}(
        spec::Union{Vector{<:IOExample}, Nothing} = nothing,
        obs_equivalence::Bool = false,
        max_bound::Int64 = typemax(Int64)
    ) <: BUBoundedIterator{T}

A concrete implementation of BUBoundedIterator that enumerates programs by their depth.
Depth is defined as:
- Terminals have depth 1
- For non-terminals: depth(op(c1,c2,...)) = 1 + maximum(depths of children)
""" DepthBoundedIterator
@programiterator DepthBoundedIterator{T}(
    spec::Union{Vector{<:IOExample}, Nothing} = nothing,
    obs_equivalence::Bool = false,
    max_bound::Int64 = typemax(Int64)
) <: BUBoundedIterator{T}

function bound_function(iter::DepthBoundedIterator{T}, program::T)::Int64 where T
    return depth(program)
end

function combine_bound_function(
    iter::DepthBoundedIterator{T}, 
    rule_idx::Int, 
    children_bounds::Vector{Int64}
)::Int64 where T
    if isempty(children_bounds)
        return 1.0  # Terminal
    else
        return 1.0 + maximum(children_bounds)  # 1 + max depth of children
    end
end