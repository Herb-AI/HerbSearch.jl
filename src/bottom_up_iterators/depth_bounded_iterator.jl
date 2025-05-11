Base.@doc """
    @programiterator DepthBoundedIterator{T}(
        spec::Union{Vector{<:IOExample}, Nothing} = nothing,
        obs_equivalence::Bool = false,
        max_bound::Float64 = typemax(Float64)
    ) <: Bounded_BU_Iterator{T}

A concrete implementation of Bounded_BU_Iterator that enumerates programs by their depth.
Depth is defined as:
- Terminals have depth 1
- For non-terminals: depth(op(c1,c2,...)) = 1 + maximum(depths of children)
""" DepthBoundedIterator
@programiterator DepthBoundedIterator{T}(
    spec::Union{Vector{<:IOExample}, Nothing} = nothing,
    obs_equivalence::Bool = false,
    max_bound::Float64 = typemax(Float64)
) <: Bounded_BU_Iterator{T}

function get_initial_bound(iter::DepthBoundedIterator{T})::Float64 where T
    return 1.0  # Terminals have depth 1
end

function bound_function(iter::DepthBoundedIterator{T}, program::T)::Float64 where T
    return Float64(depth(program))
end

function combine_bound_function(
    iter::DepthBoundedIterator{T}, 
    rule_idx::Int, 
    children_bounds::Vector{Float64}
)::Float64 where T
    if isempty(children_bounds)
        return 1.0  # Terminal
    else
        return 1.0 + maximum(children_bounds)  # 1 + max depth of children
    end
end