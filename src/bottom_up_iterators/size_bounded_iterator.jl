Base.@doc """
    @programiterator SizeBoundedIterator{T}(
        spec::Union{Vector{<:IOExample}, Nothing} = nothing,
        obs_equivalence::Bool = false,
        max_bound::Float64 = typemax(Float64)
    ) <: Bounded_BU_Iterator{T}

A concrete implementation of Bounded_BU_Iterator that enumerates programs by their size.
Size is defined as:
- Terminals have size 1
- For non-terminals: size(op(c1,c2,...)) = 1 + sum(sizes of children)
""" SizeBoundedIterator
@programiterator SizeBoundedIterator{T}(
    spec::Union{Vector{<:IOExample}, Nothing} = nothing,
    obs_equivalence::Bool = false,
    max_bound::Float64 = typemax(Float64)
) <: Bounded_BU_Iterator{T}

function get_initial_bound(iter::SizeBoundedIterator{T})::Float64 where T
    return 1.0  # Terminals have size 1
end

function bound_function(iter::SizeBoundedIterator{T}, program::T)::Float64 where T
    # If we already have a size function in the codebase, we should use that
    # Otherwise, we need to implement it
    return Float64(length(program))
end

function combine_bound_function(
    iter::SizeBoundedIterator{T}, 
    rule_idx::Int, 
    children_bounds::Vector{Float64}
)::Float64 where T
    if isempty(children_bounds)
        return 1.0  # Terminal
    else
        return 1.0 + sum(children_bounds)  # 1 + sum of children sizes
    end
end