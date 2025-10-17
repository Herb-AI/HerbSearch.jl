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

Build the full cross-product total-cost tensor for a uniform tree `tree`.

The preorder traversal order (node, then children) defines the tensor axis order.
For each axis, admissible grammar indices are taken from `node.domain`, and the
per-option cost defaults to `get_current_costs(iter)[index]`.

Returns a tuple `(totals_flat, axis_lengths, sorted_costs)`:
- `totals_flat::Vector{Float64}`  — row-major flattened totals of length `prod(axis_lengths)`
- `axis_lengths::Vector{Int}`     — per-axis lengths in preorder
- `sorted_costs::Vector{Float64}` — unique, sorted totals from `totals_flat`

Notes for customization:
Override this method if you want different costs (e.g. distance to a goal state).
"""
function build_cost_cross_product(iter::AbstractCostBasedBottomUpIterator,
                                  grammar::AbstractGrammar,
                                  tree::UniformHole)

    current_costs = get_current_costs(iter)

    # 1) Collect per-axis options (indices) and their costs in preorder.
    option_indices = Vector{Vector{Int}}()
    option_costs   = Vector{Vector{Float64}}()

    function build_axes(node::UniformHole)
        idxs = findall(node.domain)
        push!(option_indices, idxs)
        push!(option_costs, @inbounds Float64.(view(current_costs, idxs)))
        @inbounds for child in node.children
            build_axes(child)
        end
    end
    build_axes(tree)

    axis_lengths = map(length, option_indices)
    n_axes = length(axis_lengths)

    # 2) Row-major strides: stride[k] = prod(axis_lengths[k+1:end]); stride[end] = 1
    strides = similar(axis_lengths)
    s = 1
    @inbounds for k in n_axes:-1:1
        strides[k] = s
        s *= axis_lengths[k]
    end
    total_len = s

    # 3) Fill flat totals with a recursive loop.
    totals_flat = Vector{Float64}(undef, total_len)

    # Depth-first traversal over axes (equivalent to n nested loops).
    # - `k`           : which axis we’re fixing now (1..n_axes)
    # - `running`     : partial sum of costs chosen on axes 1..k-1
    # - `base_lin`    : the current linear index position contributed by axes 1..k-1
    #
    # For the current axis k, choosing option i advances the linear index by
    # (i-1) * strides[k]. We add that to `base_lin` and recurse to axis k+1.
    # When k passes n_axes, we’ve picked one option on every axis, so we write
    # the complete sum into `totals_flat` at the computed linear position.
    function fill_axis(k::Int, running::Float64, base_lin::Int)
        if k > n_axes
            @inbounds totals_flat[base_lin] = running
            return
        end
        lenk    = axis_lengths[k]
        costs_k = option_costs[k]
        step    = strides[k]
        @inbounds for i in 1:lenk
            fill_axis(k + 1, running + costs_k[i], base_lin + (i - 1) * step)
        end
    end
    fill_axis(1, 0.0, 1)

    sorted_costs = sort(unique(totals_flat))
    return totals_flat, collect(axis_lengths), sorted_costs
end


"""
    $(TYPEDSIGNATURES)

Return all Cartesian indices whose total equals `target` (≈ within tolerance).
Works in flat space and decodes linear indices back to N-D coordinates.
"""
function indices_at_cost(iter::AbstractCostBasedBottomUpIterator,
                         ent::UniformTreeEntry,
                         target::Float64)
    tolerance    = cost_match_atol(iter)
    axis_lengths = ent.dims
    num_axes     = length(axis_lengths)

    # Row-major strides
    row_strides = similar(axis_lengths)
    accum = 1
    @inbounds for k in num_axes:-1:1
        row_strides[k] = accum
        accum *= axis_lengths[k]
    end
    total_linear_len = accum

    # Result buffer; element type is concrete for this call
    matches = CartesianIndex{num_axes}[]

    # We want to stream and not vectorize here to minimize allocations.
    flat = ent.cost_flat
    @inbounds for lin in 0:(total_linear_len - 1)
        v = flat[lin + 1]
        if isapprox(v, target; atol=tolerance, rtol=0.0)
            coords = ntuple(k -> (lin ÷ row_strides[k]) % axis_lengths[k] + 1, num_axes)
            push!(matches, CartesianIndex(coords))
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

Return the index of the `n`-th `true` in `mask` (1-based).
Throws if `n` exceeds the number of `true` entries.
"""
@inline function _nth_true_index(mask::AbstractVector{Bool}, n::Int)::Int
    n ≥ 1 || throw(ArgumentError("n must be ≥ 1, got $n"))
    seen = 0
    @inbounds for i in eachindex(mask)
        if mask[i]
            seen += 1
            if seen == n
                return i
            end
        end
    end
    throw(ArgumentError("n = $n exceeds number of admissible indices ($(seen))"))
end


"""
    $(TYPEDSIGNATURES)

Find the `rank`-th Cartesian position whose flat total equals `target` within `cost_match_atol(iter)`. Scans the flat buffer and decodes the position only when the `rank`-th match is reached. Returns `CartesianIndex` or `nothing`.
"""
function find_nth_index_at_cost(iter::AbstractCostBasedBottomUpIterator,
                                ent::UniformTreeEntry,
                                target::Float64,
                                rank::Integer)
    tol = cost_match_atol(iter)
    lens = ent.dims
    n_axes = length(lens)

    # Row-major strides for mixed-radix decoding
    strides = similar(lens)
    prod_tail = 1
    @inbounds for k in n_axes:-1:1
        strides[k] = prod_tail
        prod_tail *= lens[k]
    end
    total_len = prod_tail

    found = 0
    flat  = ent.cost_flat
    @inbounds for lin in 0:(total_len - 1)
        v = flat[lin + 1]
        if isapprox(v, target; atol=tol, rtol=0.0)
            found += 1
            if found == rank
                coords = ntuple(k -> (lin ÷ strides[k]) % lens[k] + 1, n_axes)
                return CartesianIndex(coords)
            end
        end
    end
    return nothing
end


"""
    $(TYPEDSIGNATURES)

Reconstruct the `a.index`-th concrete program at total cost `a.cost` for entry `a.uh_id`,
minimizing allocations.

Strategy:
- Locate the requested Cartesian position without collecting all matches.
- Traverse the uniform tree iteratively (preorder) using parallel stacks:
  `node_stack::Vector{UniformHole}` and `next_child_stack::Vector{Int}`.
- Maintain a single `path_buf::Vector{Int}` (push when descending to a child, pop on return).
- At each node, select the rule by taking the `coords[k]`-th admissible index directly
  from the domain mask via `_nth_true_index` (no intermediate `options` vectors).
"""
function retrieve(iter::AbstractCostBasedBottomUpIterator, a::CostAccessAddress)
    bank  = get_bank(iter)
    ent   = bank.uh_index[a.uh_id]

    pos = find_nth_index_at_cost(iter, ent, a.cost, a.index)
    pos === nothing && error("retrieve: index $(a.index) out of bounds at cost=$(a.cost)")
    coords = Tuple(pos)  # one tuple built once

    # Parallel stacks (no tuple frames)
    node_stack       = UniformHole[]
    next_child_stack = Int[]
    push!(node_stack, ent.program)
    push!(next_child_stack, 0)  # 0 = "on entry" for this node

    path_buf = Int[]            # reused path vector passed to `remove_all_but!`
    axis     = 0                # which decision axis we are at in preorder

    uiter  = ent.uiter
    solver = uiter.solver
    restore!(solver); save_state!(solver)

    while !isempty(node_stack)
        node       = node_stack[end]
        next_child = next_child_stack[end]

        if next_child == 0
            # Enter node: apply the selected rule for this axis.
            axis += 1
            rule_idx = _nth_true_index(node.domain, coords[axis])
            @inbounds remove_all_but!(solver, path_buf, rule_idx)
            next_child_stack[end] = 1

        elseif next_child <= length(node.children)
            # Descend to child `next_child`.
            child_pos = next_child
            next_child_stack[end] = next_child + 1
            push!(path_buf, child_pos)
            push!(node_stack, node.children[child_pos])
            push!(next_child_stack, 0)

        else
            # Done with this node; ascend one level.
            pop!(node_stack)
            pop!(next_child_stack)
            if !isempty(path_buf)
                pop!(path_buf)
            end
        end
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
