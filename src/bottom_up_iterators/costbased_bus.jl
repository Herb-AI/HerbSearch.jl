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
get_costs(grammar::AbstractGrammar) = Float64.(abs.(grammar.log_probabilities))

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
    _indices_from_mask(mask::AbstractVector{Bool}) -> Vector{Int}

Collect indices where `mask[i] == true`. Cheaper than `findall(mask)` for hot paths.
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
    build_cost_cross_product(iter, grammar, uh) -> (flat, dims, sorted)

Construct the full N-D cross-product **cost tensor** for the uniform tree `uh`,
*without* storing any Axis/Decision objects.

Steps
1. Traverse `uh` in **preorder** (node, then children) to gather, for each node:
   - the `path` (Tuple) from the root (used later in `retrieve`);
   - the `options` (grammar rule indices allowed at that node);
   - the `costs` per option, pulled from `iter.current_costs`.
   The traversal order defines the tensor axes order.
2. For each axis `k`, broadcast-add its 1-D cost vector along axis `k` into an
   N-D zero tensor of size `dims = length.(options)`.
3. Return the flattened tensor (`vec`), the `dims`, and the `sorted` unique totals.

Returns
- `flat::Vector{Float64}`  : row-major flattened tensor, length `prod(dims)`.
- `dims::Vector{Int}`      : axis lengths in preorder.
- `sorted::Vector{Float64}`: unique sorted totals (for PQ slices etc).
"""
function build_cost_cross_product(iter::AbstractCostBasedBottomUpIterator,
                                  grammar::AbstractGrammar,
                                  uh::UniformHole)
    # Collect per-node decision info in preorder (ephemeral)
    paths      = Tuple{Vararg{Int}}[]
    options    = Vector{Int}[]
    optioncost = Vector{Float64}[]
    atom       = get_current_costs(iter)

    function visit(node::UniformHole, path::Tuple{Vararg{Int}}=())
        inds = _indices_from_mask(node.domain)
        push!(paths, path)
        push!(options, inds)
        push!(optioncost, @inbounds Float64.(view(atom, inds)))
        @inbounds for (j, ch) in pairs(node.children)
            visit(ch, (path..., j))
        end
    end
    visit(uh)

    # Build N-D tensor via Kronecker-sum of the 1-D cost vectors
    n_axes = length(options)
    dims   = map(length, options)
    T      = zeros(Float64, Tuple(dims)...)

    @inbounds for k in 1:n_axes
        c_k  = optioncost[k]                           # Vector{Float64}
        shp  = ntuple(i -> (i == k ? length(c_k) : 1), n_axes)
        T   .+= reshape(c_k, shp)                      # broadcast add on axis k
    end

    # Flatten + collect unique-sorted costs
    flat   = vec(T)
    sorted = sort!(unique!(copy(flat)))
    return flat, collect(dims), sorted
end


"""
Approximation tolerance for matching floating-point totals.
"""
cost_match_atol(::AbstractCostBasedBottomUpIterator) = 1e-6

"""
    $(TYPEDSIGNATURES)

Return all Cartesian indices in `ent.cost_flat` (reshaped by `ent.dims`) whose
value is approximately `total` within `cost_match_atol(iter)`.
"""
function indices_at_cost(iter::AbstractCostBasedBottomUpIterator,
                         ent::UniformTreeEntry,
                         total::Float64)
    atol = cost_match_atol(iter)
    T = reshape(ent.cost_flat, Tuple(ent.dims))
    return findall(@. abs(T - total) <= atol)
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

Reconstruct the `a.index`-th concrete program at total cost `a.cost` within
entry `a.uh_id`. We:

1. Reshape the flat tensor by `dims` to find all indices at `a.cost`.
2. Rebuild (ephemerally) the same preorder decision info (paths, options, costs)
   directly from the stored `UniformHole`.
3. For each axis k, select the grammar rule index from `options[k][idx[k]]` and
   restrict the solver at `paths[k]` accordingly.
"""
function retrieve(iter::AbstractCostBasedBottomUpIterator, a::CostAccessAddress)
    bank  = get_bank(iter)
    ent   = bank.uh_index[a.uh_id]

    # locate the Cartesian index
    T     = reshape(ent.cost_flat, Tuple(ent.dims))
    atol = cost_match_atol(iter)
    idxs  = findall(@. abs(T - a.cost) <= atol) # broadcast cost matching
    @boundscheck a.index ≤ length(idxs) || error("retrieve: index $(a.index) out of bounds at cost=$(a.cost)")
    idx   = Tuple(idxs[a.index])  # N-tuple of Ints

    # rebuild decisions from the uniform tree (same order as in builder)
    grammar = get_grammar(iter.solver)
    atom    = get_current_costs(iter)
    paths   = Tuple{Vararg{Int}}[]
    options = Vector{Int}[]

    function visit(node::UniformHole, path::Tuple{Vararg{Int}}=())
        inds = _indices_from_mask(node.domain)
        push!(paths, path)
        push!(options, inds)
        @inbounds for (j, ch) in pairs(node.children)
            visit(ch, (path..., j))
        end
    end
    visit(ent.program)
    @assert length(options) == length(idx)

    # apply selections to the solver
    uiter  = ent.uiter
    solver = uiter.solver
    restore!(solver); save_state!(solver)

    @inbounds for k in 1:length(idx)
        selected_rule = options[k][idx[k]]
        remove_all_but!(solver, collect(Int, paths[k]), selected_rule)
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
