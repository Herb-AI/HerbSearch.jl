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
    max_cost::Float64=Inf
) <: AbstractCostBasedBottomUpIterator

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

get_costs(grammar::AbstractGrammar) = abs.(grammar.log_probabilities)

"""
    $(TYPEDSIGNATURES)

Defines the cost of a uniform tree as the **minimum** atom cost among its domain mask.
(Used only for scalar measure/pruning; tensors below cover the full cross product.)
"""
function get_cost(grammar::AbstractGrammar, uhole::AbstractUniformHole)
    return get_cost(get_costs(grammar), uhole)
end

"""
    $(TYPEDSIGNATURES)

Minimum cost among indices selected by `uhole.domain`.
"""
function get_cost(costs::Vector{<:Number}, uhole::AbstractUniformHole) 
    return minimum(costs[collect(uhole.domain)]) + sum((get_cost(costs, c) for c in uhole.children); init=0.0)
end

"""
    $(TYPEDSIGNATURES)

The measure for a uniform hole is its **minimum** possible total cost (scalar).
"""
calc_measure(iter::AbstractCostBasedBottomUpIterator, uhole::AbstractUniformHole) = get_cost(get_grammar(iter.solver), uhole)

"""
    $(TYPEDSIGNATURES)

The measure limit is `max_cost`.
"""
get_measure_limit(iter::AbstractCostBasedBottomUpIterator) = get_max_cost(iter)

"""
    $(TYPEDEF)

A decision axis for the cross product of a uniform tree.

Fields:
- `path::Tuple{Vararg{Int}}` : path from the tree root to this node; the root path is `()`.
- `options::Vector{Int}`     : grammar indices allowed along this axis.
- `costs::Vector{Float64}`   : atom costs corresponding 1-to-1 with `options`.
"""
struct Axis
    path::Tuple{Vararg{Int}}
    options::Vector{Int}
    costs::Vector{Float64}
end


"""
    $(TYPEDEF)

A cached, fully-factorized representation of a discovered uniform tree.

Fields:
- `program::UniformHole` : the uniform tree (shape + children uniform trees).
- `axes::Vector{Axis}` : one axis per decision (operators and leaves) in **fixed order**.
- `cost_tensor::AbstractArray{Float64}` : N-D total-cost tensor of the full cross product.
- `sorted_costs::Vector{Float64}` : unique sorted list of all total costs in `cost_tensor`.
- `rtype::Symbol` : cached return type of the uniform tree (grammar type symbol).
- `new_shape::Bool` : marks whether this entry was created in the *current* wave.
- `uiter::UniformIterator` : embedded iterator for reconstructing concrete programs.
"""
mutable struct UniformTreeEntry <: AbstractBankEntry
    program::UniformHole
    axes::Vector{Axis}
    cost_tensor::AbstractArray{Float64}
    sorted_costs::Vector{Float64}
    rtype::Symbol
    new_shape::Bool
    uiter::UniformIterator
end


"""
    $(TYPEDEF)

Holds all discovered uniform trees and the global frontier.

Fields:
- `uh_index::Dict{Int,UniformTreeEntry}` : discovered uniform trees by ID.
- `pq::PriorityQueue{Tuple{Int,Int},Float64}` : maps `(uh_id, idx_in_sorted_costs) → total_cost`.
- `next_id::Base.RefValue{Int}` : monotonically increasing ID source.
- `last_horizon::Float64` : inclusive lower bound of the last emitted layer.
- `new_horizon::Float64` : exclusive upper bound of the next layer, as computed by
  `calculate_new_horizon`.
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
    Ref(1),
    -Inf,
    0
)


"""
    $(TYPEDSIGNATURES)

Collect the **decision axes** for the full cross product of `program`.

- For every leaf: add a leaf axis with all admissible terminal indices and costs.
- For every internal node: add an op axis with all admissible operator indices and costs.
- Recurse into children, extending `path` by child position.

Axes order is deterministic (preorder: node, then its children), and defines the tensor axes.
"""
function build_axes(grammar::AbstractGrammar, program::UniformHole; path::Tuple{Vararg{Int}}=())
    axes = Axis[]

    if isempty(program.children)
        term_inds  = findall(program.domain)
        term_costs = Float64.(get_costs(grammar)[term_inds])
        push!(axes, Axis(path, term_inds, term_costs))
        return axes
    end

    op_inds  = findall(program.domain)
    op_costs = Float64.(get_costs(grammar)[op_inds])
    push!(axes, Axis(path, op_inds, op_costs))

    @inbounds for (j, ch) in pairs(program.children)
        child_path = (path..., j)
        append!(axes, build_axes(grammar, ch; path=child_path))
    end
    return axes
end


"""
    $(TYPEDSIGNATURES)

Given `axes`, produce an N-D tensor `T` whose entry at a Cartesian index `(i₁,…,i_N)`
equals `sum_k axes[k].costs[i_k]`.
"""
function build_cost_tensor(axes::Vector{Axis})
    N    = length(axes)
    dims = ntuple(k -> length(axes[k].options), N)
    T    = zeros(Float64, dims...)
    for k in 1:N
        v   = axes[k].costs
        shp = ntuple(i -> i == k ? length(v) : 1, N)
        T  .+= reshape(v, shp)
    end
    return T
end

"""
    $(TYPEDSIGNATURES)

Unique, sorted list of all total costs in a tensor.
"""
unique_sorted_costs(T::AbstractArray{<:Real}) = sort!(unique!(collect(vec(T))))


"""
    $(TYPEDSIGNATURES)

Build the full cross-product for `program`.
"""
function build_cost_cross_product(grammar::AbstractGrammar, program::UniformHole)
    axes = build_axes(grammar, program)
    T    = build_cost_tensor(axes)
    return axes, T, unique_sorted_costs(T)
end


"""
Approximation tolerance for matching floating-point totals.
"""
cost_match_atol(::AbstractCostBasedBottomUpIterator) = 1e-6

"""
    $(TYPEDSIGNATURES)

Return all Cartesian indices in `ent.cost_tensor` whose value ≈ `total` (within `atol`).
"""
function indices_at_cost(iter::AbstractCostBasedBottomUpIterator,
                         ent::UniformTreeEntry,
                         total::Float64)
    atol = cost_match_atol(iter)
    return findall(x -> isapprox(x, total; atol=atol, rtol=0.0), ent.cost_tensor)
end

"""
convert to Vector of ints explicitly, due to empty tuples
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
    return nothing
end


"""
    $(TYPEDSIGNATURES)

Add a newly discovered uniform tree to the bank, mark it as `new_shape = true`, and
return its assigned `uh_id`. The caller is responsible for enqueuing its costs via
`enqueue_entry_costs!`.
"""
function add_to_bank!(iter::AbstractCostBasedBottomUpIterator, program::AbstractRuleNode)::Int
    grammar = get_grammar(iter.solver)
    bank    = get_bank(iter)

    # Caculate all possible costs
    axes, T, sorted_costs = build_cost_cross_product(grammar, program)
    rtype = HerbGrammar.return_type(grammar, program)
    uh_id = (bank.next_id[] += 1) - 1

    # Construct UniformIterator for the uniform tree
    usolver = UniformSolver(grammar, program, with_statistics=get_solver(iter).statistics)
    uiter = UniformIterator(usolver, iter)

    bank.uh_index[uh_id] = UniformTreeEntry(program, axes, T, sorted_costs, rtype, true, uiter)
    return uh_id
end


"""
    $(TYPEDSIGNATURES)

Compute the **lowest possible total cost** of any *new parent shape* formed by combining
children where **at least one** child has `new_shape == true`. Returns `Inf` if no such
combination exists or none are within `max_cost`.
"""
function compute_new_horizon(iter::AbstractCostBasedBottomUpIterator, state::GenericBUState)
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

        op_min = minimum(get_costs(grammar)[shape.domain])

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

Return the `a.index`-th concrete program in entry `a.uh_id` at total cost `a.cost`,
by fixing all decisions in the entry's embedded `UniformIterator`.
"""
function retrieve(iter::AbstractCostBasedBottomUpIterator, a::CostAccessAddress)
    ent   = get_bank(iter).uh_index[a.uh_id]
    idxs  = indices_at_cost(iter, ent, a.cost)
    @boundscheck a.index ≤ length(idxs) || error("retrieve: index $(a.index) out of bounds at cost=$(a.cost)")
    idx   = Tuple(idxs[a.index])

    uiter  = ent.uiter
    solver = uiter.solver

    # backtrack from the previous solution
    restore!(solver)
    save_state!(solver)

    @inbounds for k in 1:length(ent.axes)
        ax       = ent.axes[k]
        rule_idx = ax.options[idx[k]]
        remove_all_but!(solver, _pathvec(ax.path), rule_idx)
    end

    # Check whether solver solver is infeasible
    if !solver.isfeasible 
        return nothing
    end

    sol = solver.tree
    return sol
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

    for uh_id in added_ids
        enqueue_entry_costs!(iter, uh_id)
    end

    bank.last_horizon = bank.new_horizon
    bank.new_horizon  = calculate_new_horizon(iter)

    out   = CostAccessAddress[]
    limit = get_measure_limit(iter)

    for (key, cost) in bank.pq
        if cost ≥ bank.last_horizon && cost < bank.new_horizon && cost ≤ limit
            (uh_id, _idx_in_sorted) = key
            ent  = bank.uh_index[uh_id]
            idxs = indices_at_cost(iter, ent, cost)
            @inbounds for i in 1:length(idxs)
                push!(out, CostAccessAddress(uh_id, cost, i))
            end
        end
    end

    sort!(out; by = a -> a.cost)
    return out, state
end


"""
    $(TYPEDSIGNATURES)

Initialize the bank with **terminal** uniform trees (one per grammar type with terminals),
mark them as `new_shape=true`, enqueue their costs, compute the initial `new_horizon`,
and **return all `CostAccessAddress` items with cost in `[last_horizon, new_horizon)`**.
"""
function populate_bank!(iter::AbstractCostBasedBottomUpIterator)
    grammar = get_grammar(iter.solver)
    bank    = get_bank(iter)

    new_ids = Int[]
    for t in unique(grammar.types)
        term_mask = grammar.isterminal .& grammar.domains[t]
        if any(term_mask)
            uh = UniformHole(term_mask, [])
            uh_id = add_to_bank!(iter, uh)
            push!(new_ids, uh_id)
        end
    end

    # Incrementally enqueue only the new seed entries
    for uh_id in new_ids
        enqueue_entry_costs!(iter, uh_id)
    end

    # Establish the very first horizon boundary
    bank.new_horizon = calculate_new_horizon(iter)

    # Collect all addresses within the initial window [last_horizon, new_horizon)
    out   = CostAccessAddress[]
    limit = get_measure_limit(iter)
    for (key, cost) in bank.pq
        if cost ≥ bank.last_horizon && cost < bank.new_horizon && cost ≤ limit
            (uh_id, _idx) = key
            ent  = bank.uh_index[uh_id]
            idxs = indices_at_cost(iter, ent, cost)
            @inbounds for i in 1:length(idxs)
                push!(out, CostAccessAddress(uh_id, cost, i))
            end
        end
    end
    sort!(out; by = a -> a.cost)
    return out
end


"""
    $(TYPEDSIGNATURES)

Call `combine` when needed to fill the current wave window. Otherwise pop the next
`CostAccessAddress`, reconstruct its concrete program, and yield it.
"""
function Base.iterate(iter::AbstractCostBasedBottomUpIterator, state::GenericBUState)
    # Construct new combinations if empty
    if isempty(state.combinations)
        addrs, _ = combine(iter, state)
        if isempty(addrs)
            return nothing
        end
        state.combinations = addrs
    end

    addr = popfirst!(state.combinations)
    prog = retrieve(iter, addr)
    return prog, state
end
