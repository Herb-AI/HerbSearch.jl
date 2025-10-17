"""
    $(TYPEDEF)

Abstract supertype for cost-ordered bottom-up iterators.
Concrete implementations are expected to provide at least:
- `get_bank(iter)`
- `get_solver(iter)` and `get_grammar(get_solver(iter))`
- storage for `max_cost`
"""
abstract type AbstractCostBasedBottomUpIterator <: BottomUpIterator end

@programiterator CostBasedBottomUpIterator(
    bank=CostBank(),
    max_cost::Float64=Inf,
    current_costs::Vector{Float64}=Float64[]
) <: AbstractCostBasedBottomUpIterator

function CostBasedBottomUpIterator(args...; kwargs...)
    raw = Float64.(abs.(grammar.log_probabilities))
    CostBasedBottomUpIterator(args...;current_costs=raw, kwargs...)
end


@doc """
    CostBasedBottomUpIterator(; max_cost=Inf) <: AbstractCostBasedBottomUpIterator

A bottom-up, cost-ordered enumerator that advances in **waves** between horizons
`[last_horizon, new_horizon)`. Each wave emits all cost slices reachable **without**
using any newly created uniform-tree shapes. The next horizon is the lowest possible
total cost of a *new* parent shape formed by combining children where at least one
child was created in the previous wave.

We assume costs given in the grammar's log_probabilities. 
This iterator directly works with probabilistic grammars, as we take the absolute of the log_probabilities.
""" CostBasedBottomUpIterator

"""
    $(TYPEDSIGNATURES)

Returns the maximum allowed total cost for enumeration.
"""
get_max_cost(iter::AbstractCostBasedBottomUpIterator) = iter.max_cost

@inline function min_on_mask(costs::AbstractVector{<:Real}, mask)::Float64
    min_cost = Inf
    @inbounds @simd for i in eachindex(costs, mask)
        if mask[i]
            cost = Float64(costs[i])
            if cost < min_cost
                min_cost = ccost
            end
        end
    end
    return min_cost
end


get_cost(iter::AbstractCostBasedBottomUpIterator, uhole::UniformHole) = get_cost(get_current_costs(iter), uhole)

"""
Returns the costs for all rules in a grammar. Transforms probabilistic grammars to their cost-based formulation by taking the absolute of the log_probabilities.
"""
function get_costs(grammar::AbstractGrammar)
    if isnothing(grammar.log_probabilities)
        throw(ArgumentError("grammar is not probabilistic. Consider calling `init_probabilities!(grammar)`"))
    end
    return Float64.(abs.(grammar.log_probabilities))
end

"""
Calculates minimum cost within a uniform tree.
"""
calc_measure(iter::AbstractCostBasedBottomUpIterator, uhole::UniformHole) = _get_cost(iter, uhole)

get_current_costs(iter::AbstractCostBasedBottomUpIterator) = iter.current_costs

"""
    $(TYPEDSIGNATURES)

Defines the cost of a uniform tree as the **minimum** atom cost among its domain mask.
(Used only for scalar measure/pruning; tensors below cover the full cross product.)
"""
get_cost(grammar::AbstractGrammar, uhole::UniformHole) = get_cost(get_costs(grammar), uhole)

"""
    $(TYPEDSIGNATURES)

Minimum cost among indices selected by `uhole.domain`.
"""
function _get_cost(costs::AbstractVector{<:Real}, uhole::AbstractUniformHole)::Float64
    acc = min_on_mask(costs, uhole.domain)
    @inbounds for ch in uhole.children
        acc += get_cost(costs, ch)
    end
    return acc
end

"""
    $(TYPEDSIGNATURES)

The measure limit is `max_cost`.
"""
get_measure_limit(iter::AbstractCostBasedBottomUpIterator) = get_max_cost(iter)


"""
    UniformTreeEntry

Cached representation of a discovered uniform tree.

Fields
- `program::UniformHole`        : the uniform tree.
- `cost_flat::Vector{Float64}`  : flattened N-D total-cost tensor of the full cross product.
- `dims::Vector{Int}`           : the length of each tensor axis (same order as preorder traversal).
- `sorted_costs::Vector{Float64}` : unique, sorted list of all totals in `cost_flat`.
- `rtype::Symbol`               : cached return type (grammar type symbol).
- `new_shape::Bool`             : whether it was created in the *current* wave.
- `uiter::UniformIterator`      : iterator for reconstructing concrete programs.
"""
mutable struct UniformTreeEntry <: AbstractBankEntry
    program::UniformHole
    cost_flat::Vector{Float64}
    dims::Vector{Int}
    sorted_costs::Vector{Float64}
    rtype::Symbol
    new_shape::Bool
    uiter::UniformIterator
end

"""
    CostBank

Holds all discovered uniform trees and the global frontier.

Fields
- `uh_index::Dict{Int,UniformTreeEntry}`     : discovered trees by ID.
- `pq::PriorityQueue{Tuple{Int,Int},Float64}`: maps `(uh_id, idx_in_sorted_costs) → total_cost`.
- `next_id::Base.RefValue{Int}`              : monotonically increasing ID source.
"""
mutable struct CostBank
    uh_index::Dict{Int,UniformTreeEntry}
    pq::PriorityQueue{Tuple{Int,Int}, Float64}
    next_id::Base.RefValue{Int}
end

"""
Create an empty bank.
"""
CostBank() = CostBank(
    Dict{Int,UniformTreeEntry}(),
    PriorityQueue{Tuple{Int,Int}, Float64}(),
    Ref(1)
)

"""
    $(TYPEDSIGNATURES)

Collect indices i where `mask[i] == true`. Faster and clearer than `findall(mask)`
in hot paths because it avoids building an intermediate bitset vector first.
"""
function _indices_from_mask(mask)::Vector{Int}
    idxs = Int[]
    sizehint!(idxs, count(mask))
    @inbounds for (i, b) in pairs(mask)
        b && push!(idxs, i)
    end
    return idxs
end

"""
Approximation tolerance for matching floating-point totals.
"""
cost_match_atol(::AbstractCostBasedBottomUpIterator) = 1e-6

"""
    $(TYPEDSIGNATURES)

Return indices `i` where `mask[i] == true`. Avoids the extra work of `findall(mask)`.
"""
function _indices_from_mask(mask::AbstractVector{Bool})::Vector{Int}
    indices = Int[]
    sizehint!(indices, count(mask))
    @inbounds for (i, bit) in pairs(mask)
        bit && push!(indices, i)
    end
    return indices
end

"""
    $(TYPEDSIGNATURES)

Build the cross-product total-cost tensor for uniform tree `uh` directly from the
iterator’s `current_costs`. The tensor is stored flat along with its axis lengths.

Returns a tuple `(totals_flat, axis_lengths, sorted_costs)` where:
- `totals_flat::Vector{Float64}`  — row-major flattened totals, length `prod(axis_lengths)`.
- `axis_lengths::Vector{Int}`     — length of each decision axis in preorder.
- `sorted_costs::Vector{Float64}` — unique, sorted list of totals (useful for PQ slices).
"""
function build_cost_cross_product(iter::AbstractCostBasedBottomUpIterator,
                                  grammar::AbstractGrammar,
                                  uh::UniformHole)
    current_costs = get_current_costs(iter)

    # Preorder traversal (explicit stack) to collect per-axis options and their costs
    option_index_lists  = Vector{Int}[]          # admissible grammar indices per axis
    option_cost_lists   = Vector{Float64}[]      # costs per option, aligned with indices
    stack = Vector{Tuple{UniformHole,Int}}(undef, 0)  # (node, next_child_idx); 0 == "on entry"
    push!(stack, (uh, 0))

    while !isempty(stack)
        node, next_child = stack[end]

        if next_child == 0
            idxs = _indices_from_mask(node.domain)
            push!(option_index_lists, idxs)
            push!(option_cost_lists, @inbounds Float64.(view(current_costs, idxs)))
            stack[end] = (node, 1)
        elseif next_child <= length(node.children)
            child = node.children[next_child]
            stack[end] = (node, next_child + 1)
            push!(stack, (child, 0))
        else
            pop!(stack)
        end
    end

    axis_lengths = map(length, option_index_lists)
    num_axes     = length(axis_lengths)
    if num_axes == 0
        return Float64[], Int[], Float64[]
    end

    # Row-major strides: stride[k] = prod(axis_lengths[k+1:end]); stride[end] = 1
    row_strides = similar(axis_lengths)
    accum = 1
    @inbounds for k in num_axes:-1:1
        row_strides[k] = accum
        accum *= axis_lengths[k]
    end
    total_linear_length = accum  # == prod(axis_lengths)

    # Fill the flat totals using mixed-radix decoding of each linear index
    totals_flat = Vector{Float64}(undef, total_linear_length)
    @inbounds for linear_index in 0:(total_linear_length - 1)
        total = 0.0
        for k in 1:num_axes
            axis_coord = (linear_index ÷ row_strides[k]) % axis_lengths[k] + 1
            total += option_cost_lists[k][axis_coord]
        end
        totals_flat[linear_index + 1] = total
    end

    sorted_costs = sort!(unique!(copy(totals_flat)))
    return totals_flat, collect(axis_lengths), sorted_costs
end

"""
    $(TYPEDSIGNATURES)

Return all Cartesian indices of the conceptual N-D tensor (defined by `ent.dims`)
whose flat value equals `total` within `cost_match_atol(iter)`.

This scans the flat buffer and decodes each matching linear index back to a
`CartesianIndex` using the precomputed axis lengths.
"""
function indices_at_cost(iter::AbstractCostBasedBottomUpIterator,
                         ent::UniformTreeEntry,
                         total::Float64)
    tolerance    = cost_match_atol(iter)
    axis_lengths = ent.dims
    num_axes     = length(axis_lengths)

    # Compute row-major strides once so we can decode linear → Cartesian cheaply.
    row_strides = similar(axis_lengths)
    accum = 1
    @inbounds for k in num_axes:-1:1
        row_strides[k] = accum
        accum *= axis_lengths[k]
    end
    total_linear_length = accum

    matches = CartesianIndex{num_axes}[]
    flat    = ent.cost_flat

    @inbounds for linear_index in 0:(total_linear_length - 1)
        value = flat[linear_index + 1]
        if isapprox(value, total; atol=tolerance, rtol=0.0)
            # Decode the linear position into a 1-based Cartesian coordinate tuple.
            cartesian = ntuple(k -> (linear_index ÷ row_strides[k]) % axis_lengths[k] + 1,
                               num_axes)
            push!(matches, CartesianIndex(cartesian))
        end
    end
    return matches
end


"""
Convert to Vector of ints explicitly, due to empty tuples.
"""
_pathvec(path::Tuple{Vararg{Int}}) = collect(Int, path)


"""
    $(TYPEDSIGNATURES)

Push **all** `(uh_id, idx)` cost-slices for the given entry into the bank's PQ,
capped by `get_max_cost(iter)`. This is **incremental**: it does not clear the PQ.
"""
function enqueue_entry_costs!(iter::AbstractCostBasedBottomUpIterator, uh_id::Int)
    bank  = get_bank(iter)
    ent   = bank.uh_index[uh_id]
    limit = get_measure_limit(iter)
    @inbounds for (i, c) in pairs(ent.sorted_costs)
        if c ≤ limit
            enqueue!(bank.pq, (uh_id, i), c)
        end
    end
end


"""
    $(TYPEDSIGNATURES)

Create a new `UniformTreeEntry` and add it to the bank by building the cross-product cost tensor directly from `program`, enqueue its cost slices into the bank PQ, and return the assigned ID.
"""
function add_to_bank!(iter::AbstractCostBasedBottomUpIterator,
                      program::UniformHole)::Int
    grammar = get_grammar(iter.solver)
    bank    = get_bank(iter)

    flat, dims, sorted_costs = build_cost_cross_product(iter, grammar, program)
    rtype = HerbGrammar.return_type(grammar, program)
    uh_id = (bank.next_id[] += 1) - 1

    usolver = UniformSolver(grammar, program, with_statistics=get_solver(iter).statistics)
    uiter   = UniformIterator(usolver, iter)

    bank.uh_index[uh_id] = UniformTreeEntry(program, flat, dims, sorted_costs, rtype, true, uiter)
    enqueue_entry_costs!(iter, uh_id)
    return uh_id
end


function seed_terminals!(iter::AbstractCostBasedBottomUpIterator)
    grammar = get_grammar(iter.solver)
    bank    = get_bank(iter)

    for t in unique(grammar.types)
        term_mask = grammar.isterminal .& grammar.domains[t]
        if any(term_mask)
            uh = UniformHole(term_mask, [])
            _ = add_to_bank!(iter, uh)  # marks new_shape=true internally
        end
    end
    return nothing
end

function collect_initial_window(iter::AbstractCostBasedBottomUpIterator)
    bank  = get_bank(iter)
    limit = get_measure_limit(iter)

    out = CostAccessAddress[]
    for (uh_id, ent) in bank.uh_index
        for c in ent.sorted_costs
            if c ≤ limit
                idxs = indices_at_cost(iter, ent, c)
                @inbounds for i in 1:length(idxs)
                    push!(out, CostAccessAddress(uh_id, c, i))
                end
            end
        end
    end
    return out
end



"""
    $(TYPEDSIGNATURES)

Compute the **lowest possible total cost** of any *new parent shape* formed by combining
children where **at least one** child has `new_shape == true`. Returns `Inf` if no such
combination exists or none are within `max_cost`.
"""
function compute_new_horizon(iter::AbstractCostBasedBottomUpIterator)
    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)
    limit   = get_measure_limit(iter)

    bytype = Dict{Symbol, Vector{UniformTreeEntry}}()
    for (_, ent) in bank.uh_index
        push!(get!(bytype, ent.rtype, UniformTreeEntry[]), ent)
    end

    terminals = grammar.isterminal
    nonterm   = .~terminals
    shapes    = UniformHole.(partition(Hole(nonterm), grammar), ([],))

    best = Inf

    for shape in shapes
        rule_idx = findfirst(shape.domain)
        rule_idx === nothing && continue
        child_types = Tuple(grammar.childtypes[rule_idx])

        candidate_lists = Vector{Vector{UniformTreeEntry}}(undef, length(child_types))
        feasible = true
        @inbounds for i in 1:length(child_types)
            lst = get(bytype, child_types[i], nothing)
            if lst === nothing || isempty(lst)
                feasible = false; break
            end
            candidate_lists[i] = lst
        end
        feasible || continue

        op_min = minimum(@view get_current_costs(iter)[shape.domain])

        for tuple_children in Iterators.product(candidate_lists...)
            any_new = any(e.new_shape for e in tuple_children)
            any_new || continue
            lb = op_min
            @inbounds for e in tuple_children
                lb += e.sorted_costs[1]
            end
            if lb < best && lb ≤ limit
                best = lb
            end
        end
    end

    return best
end


"""
    CostAccessAddress <: AbstractAddress

Address to a **concrete** program at a particular cost within a specific uniform tree.

Fields:
- `uh_id::Int` : which uniform tree in the bank.
- `cost::Float64` : total cost to select within this tree's tensor.
- `index::I` : 1-based rank within all concrete programs at that cost for the tree.
"""
struct CostAccessAddress{I<:Integer} <: AbstractAddress
    uh_id::Int
    cost::Float64
    index::I
end

"""
    $(TYPEDSIGNATURES)

Get the measure (cost) of a `CostAccessAddress`.
"""
get_measure(a::CostAccessAddress) = a.cost

"""
    $(TYPEDSIGNATURES)

Get the concrete index within the cost-slice.
"""
get_index(a::CostAccessAddress) = a.index


"""
    $(TYPEDSIGNATURES)

Reconstruct the `a.index`-th concrete program at total cost `a.cost` for entry `a.uh_id`.
Uses the same preorder traversal used during cross-product construction to rebuild
paths and options, then applies the chosen rules to the solver.
"""
function retrieve(iter::AbstractCostBasedBottomUpIterator, a::CostAccessAddress)
    bank  = get_bank(iter)
    entry = bank.uh_index[a.uh_id]

    # Find all Cartesian positions matching the target total, then select the requested rank.
    hits = indices_at_cost(iter, entry, a.cost)
    @boundscheck a.index ≤ length(hits) || error("retrieve: index $(a.index) out of bounds at cost=$(a.cost)")
    coords = Tuple(hits[a.index])  # N-tuple of Ints

    # Rebuild preorder (paths, options) via explicit stack so axis order matches the builder.
    paths   = Tuple{Vararg{Int}}[]
    options = Vector{Int}[]
    stack = Vector{Tuple{UniformHole,Int,Tuple{Vararg{Int}}}}(undef, 0)  # (node, next_child, path)
    push!(stack, (entry.program, 0, ()))

    while !isempty(stack)
        node, next_child, path = stack[end]

        if next_child == 0
            push!(paths, path)
            push!(options, _indices_from_mask(node.domain))
            stack[end] = (node, 1, path)
        elseif next_child <= length(node.children)
            child = node.children[next_child]
            stack[end] = (node, next_child + 1, path)
            push!(stack, (child, 0, (path..., next_child)))
        else
            pop!(stack)
        end
    end
    @assert length(options) == length(coords)

    # Apply the chosen rules along each path to reconstruct a concrete program.
    uiter  = entry.uiter
    solver = uiter.solver
    restore!(solver); save_state!(solver)

    @inbounds for k in 1:length(coords)
        rule_index = options[k][coords[k]]
        remove_all_but!(solver, collect(Int, paths[k]), rule_index)
    end

    return solver.isfeasible ? solver.tree : nothing
end


"""
    $(TYPEDSIGNATURES)

Wavefront expansion:

1. Construct all *new* parent shapes (use ≥1 child with `new_shape=true`), add to bank.
2. Flip flags: all entries that *were* `new_shape` at the start become `false`.
3. Incrementally enqueue PQ entries for **only the newly added** parents.
4. Slide the horizon window: `last_horizon = new_horizon`; recompute `new_horizon`.
5. Return addresses with cost in `[last_horizon, new_horizon)` (and `≤ max_cost`),
   sorted increasing by total cost. 
"""
function combine(iter::AbstractCostBasedBottomUpIterator, state::GenericBUState)
    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)

    size_limit = get_max_size(iter)
    depth_limit = get_max_depth(iter)

    state.last_horizon = state.new_horizon
    state.new_horizon  = compute_new_horizon(iter)

    newly_flagged_ids = Set{Int}()
    for (id, ent) in bank.uh_index
        if ent.new_shape
            push!(newly_flagged_ids, id)
        end
    end

    bytype = Dict{Symbol, Vector{Tuple{Int,UniformTreeEntry}}}()
    for (id, ent) in bank.uh_index
        push!(get!(bytype, ent.rtype, Tuple{Int,UniformTreeEntry}[]), (id, ent))
    end

    terminals = grammar.isterminal
    nonterm   = .~terminals
    shapes    = UniformHole.(partition(Hole(nonterm), grammar), ([],))

    added_ids = Int[]

    new_horizon = Inf
    for shape in shapes
        rule_idx = findfirst(shape.domain)
        rule_idx === nothing && continue
        child_types = Tuple(grammar.childtypes[rule_idx])

        candidates = Vector{Vector{Tuple{Int,UniformTreeEntry}}}(undef, length(child_types))
        feasible = true
        @inbounds for i in 1:length(child_types)
            lst = get(bytype, child_types[i], nothing)
            if lst === nothing || isempty(lst)
                feasible = false; break
            end
            candidates[i] = lst
        end
        feasible || continue

        for tuple_children in Iterators.product(candidates...)
            any_new = any( (id ∈ newly_flagged_ids) for (id, _e) in tuple_children )
            any_new || continue # At least one newly found shape must be present
            parent_hole = UniformHole(shape.domain, UniformHole[e.program for (_id, e) in tuple_children])
            if length(parent_hole) > size_limit || 
               depth(parent_hole) > depth_limit 
                continue
            end
            uh_id = add_to_bank!(iter, parent_hole) 
            
            push!(added_ids, uh_id)
        end
    end

    for id in newly_flagged_ids
        bank.uh_index[id].new_shape = false
    end

    limit = get_measure_limit(iter)

    for (key, cost) in bank.pq
        if cost ≥ state.last_horizon && cost < state.new_horizon && cost ≤ limit
            (uh_id, _idx_in_sorted) = key
            ent  = bank.uh_index[uh_id]
            idxs = indices_at_cost(iter, ent, cost)
            @inbounds for i in 1:length(idxs)
                addrs = CostAccessAddress(uh_id, cost, i)
                if !haskey(state.combinations, addrs)
                    enqueue!(state.combinations, addrs, cost)
                end
            end
        end
    end

    return state.combinations, state
end

"""
    $(TYPEDSIGNATURES)

Call `combine` when needed to fill the current wave window. Otherwise pop the next
`CostAccessAddress`, reconstruct its concrete program, and yield it.
"""
function Base.iterate(iter::AbstractCostBasedBottomUpIterator, state::GenericBUState)
    next_program_address, new_state = get_next_program(iter, state)

    while !isnothing(next_program_address)
        program = retrieve(iter, next_program_address)

        if is_subdomain(program, state.starting_node)
            return program, state
        end

        next_program_address, new_state = get_next_program(iter, new_state)
    end

    return nothing
end
