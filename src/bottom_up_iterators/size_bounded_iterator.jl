Base.@doc """
    @programiterator SizeBoundedIterator{T}(
        spec::Union{Vector{<:IOExample}, Nothing} = nothing,
        obs_equivalence::Bool = false,
        max_bound::Int64 = typemax(Int64)
    ) <: BUBoundedIterator{T}

A concrete implementation of BUBoundedIterator that enumerates programs by their size.
Size is defined as:
- Terminals have size 1
- For non-terminals: size(op(c1,c2,...)) = 1 + sum(sizes of children)
""" SizeBoundedIterator
@programiterator SizeBoundedIterator{T}(
    spec::Union{Vector{<:IOExample}, Nothing} = nothing,
    obs_equivalence::Bool = false,
    max_bound::Int64 = typemax(Int64)
) <: BUBoundedIterator{T}

function bound_function(iter::SizeBoundedIterator{T}, program::T)::Int64 where T
    return length(program)
end

function combine_bound_function(
    iter::SizeBoundedIterator{T}, 
    rule_idx::Int, 
    children_bounds::Vector{Int64}
)::Int64 where T
    if isempty(children_bounds)
        return 1  # Terminal
    else
        return 1 + sum(children_bounds)  # 1 + sum of children sizes
    end
end