"""
    count_programs(grammar::AbstractGrammar, start_symbol::Symbol; max_depth=nothing, max_size=nothing, numtype=BigInt)

Counts how many programs of type `start_symbol` a grammar holds, without enumerating them.
At least one of `max_depth` and `max_size` has to be given; providing both counts the
programs satisfying both bounds simultaneously.

`max_depth` is bounded the same way [`depth`](@ref) measures it, i.e. a single terminal has
depth 1. `max_size` is bounded the same way `length` measures it, i.e. the number of nodes
in the tree.

Constraints of a [`ContextSensitiveGrammar`](@ref) are *not* taken into account, so for a
constrained grammar the result is an upper bound on the number of programs an iterator
yields.

Counts grow doubly exponentially in the depth, which is why they are computed with `BigInt`
by default. Pass `numtype=Int` for speed if the result is known to fit, but note that
overflow is silent.

```jldoctest
julia> g = @csgrammar begin
           Real = 1 | 2
           Real = Real * Real
       end;

julia> count_programs(g, :Real, max_depth=2)
6

julia> count_programs(g, :Real, max_size=5)
22

julia> count_programs(g, :Real, max_depth=3, max_size=5)
22
```
"""
function count_programs(
    grammar::AbstractGrammar,
    start_symbol::Symbol;
    max_depth::Union{Int,Nothing}=nothing,
    max_size::Union{Int,Nothing}=nothing,
    numtype::Type{<:Integer}=BigInt
)::Integer
    _assert_symbol(grammar, start_symbol)
    if isnothing(max_depth) && isnothing(max_size)
        throw(ArgumentError("At least one of `max_depth` and `max_size` must be given, otherwise the number of programs is unbounded."))
    end

    if isnothing(max_size)
        return _count_by_depth(grammar, max_depth, numtype)[start_symbol]
    end
    return sum(
        count_programs_by_size(grammar, start_symbol, max_size; max_depth, numtype);
        init=zero(numtype)
    )
end

"""
    count_programs_by_size(grammar::AbstractGrammar, start_symbol::Symbol, max_size::Int; max_depth=nothing, numtype=BigInt)

Returns a vector `v` of length `max_size`, where `v[s]` is the number of programs of type
`start_symbol` consisting of exactly `s` nodes (and of depth at most `max_depth`, if given).
See [`count_programs`](@ref) for the conventions and caveats.

```jldoctest
julia> g = @csgrammar begin
           Real = 1 | 2
           Real = Real * Real
       end;

julia> count_programs_by_size(g, :Real, 5)
5-element Vector{BigInt}:
  2
  0
  4
  0
 16
```
"""
function count_programs_by_size(
    grammar::AbstractGrammar,
    start_symbol::Symbol,
    max_size::Int;
    max_depth::Union{Int,Nothing}=nothing,
    numtype::Type{<:Integer}=BigInt
)::Vector{<:Integer}
    _assert_symbol(grammar, start_symbol)
    max_size ≤ 0 && return zeros(numtype, 0)

    # A program of at most `max_size` nodes has depth at most `max_size`, so bounding the
    # depth by `max_size` does not lose any program. This lets a single depth-layered
    # recursion handle the depth-only, size-only and combined case.
    depth_bound = isnothing(max_depth) ? max_size : min(max_depth, max_size)
    depth_bound ≤ 0 && return zeros(numtype, max_size)

    types = collect(keys(grammar.bytype))
    # `counts[type][s]` = number of programs of that type with exactly `s` nodes and a depth
    # of at most the depth of the current layer. The layer for depth 0 is all-zeros.
    counts = Dict(type => zeros(numtype, max_size) for type ∈ types)
    for _ ∈ 1:depth_bound
        next = Dict(type => zeros(numtype, max_size) for type ∈ types)
        for type ∈ types, rule ∈ grammar[type]
            childtypes = child_types(grammar, rule)
            if isempty(childtypes)
                next[type][1] += one(numtype)
                continue
            end
            # The rule itself takes up one node, the children share the remaining budget.
            children_counts = _count_children(counts, childtypes, max_size - 1, numtype)
            for s ∈ eachindex(children_counts)
                next[type][s+1] += children_counts[s]
            end
        end
        counts = next
    end
    return counts[start_symbol]
end

"""
    _count_children(counts::Dict{Symbol,<:Vector}, childtypes::Vector{Symbol}, budget::Int, numtype)

Returns a vector `v` of length `budget`, where `v[s]` is the number of ways to fill the
`childtypes` with programs from `counts` such that they take up exactly `s` nodes in total.
This is the (truncated) convolution of the per-child counts.
"""
function _count_children(
    counts::Dict{Symbol,<:Vector},
    childtypes::Vector{Symbol},
    budget::Int,
    numtype::Type{<:Integer}
)::Vector{<:Integer}
    budget < length(childtypes) && return zeros(numtype, max(budget, 0))
    # `combined[s+1]` = number of ways to fill the children handled so far with `s` nodes.
    combined = zeros(numtype, budget + 1)
    combined[1] = one(numtype)
    for childtype ∈ childtypes
        child_counts = counts[childtype]
        next = zeros(numtype, budget + 1)
        for used ∈ 0:budget
            iszero(combined[used+1]) && continue
            for s ∈ 1:(budget-used)
                iszero(child_counts[s]) && continue
                next[used+s+1] += combined[used+1] * child_counts[s]
            end
        end
        combined = next
    end
    return combined[2:end]
end

"""
    _count_by_depth(grammar::AbstractGrammar, max_depth::Int, numtype)

Returns a dictionary mapping every type of the grammar to the number of programs of that
type with a depth of at most `max_depth`.
"""
function _count_by_depth(
    grammar::AbstractGrammar,
    max_depth::Int,
    numtype::Type{<:Integer}
)::Dict{Symbol,<:Integer}
    types = collect(keys(grammar.bytype))
    counts = Dict(type => zero(numtype) for type ∈ types)
    for _ ∈ 1:max_depth
        next = Dict(type => zero(numtype) for type ∈ types)
        for type ∈ types, rule ∈ grammar[type]
            # Every child is a program of at most the previous depth; terminals contribute
            # the empty product, i.e. one program.
            combinations = one(numtype)
            for childtype ∈ child_types(grammar, rule)
                combinations *= counts[childtype]
                iszero(combinations) && break
            end
            next[type] += combinations
        end
        counts = next
    end
    return counts
end

function _assert_symbol(grammar::AbstractGrammar, symbol::Symbol)
    if !haskey(grammar.bytype, symbol)
        throw(ArgumentError("The grammar has no rules for symbol :$symbol."))
    end
end
