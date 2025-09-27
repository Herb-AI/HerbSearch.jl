@programiterator CostBasedBottomUpIterator(
    bank=CostBank(),
    max_cost::Float64=Inf
) <: BottomUpIterator


@doc """
    CostBasedBottomUpIterator

A bottom-up search iterator that enumerates programs in **non-decreasing total cost**.

Key ideas:

- The bank has **two** pieces:
  1. `uh_index`: a dictionary mapping `uh_id::Int` to a [`UniformTreeEntry`](@ref) that
     stores a discovered uniform tree (`UniformHole`) and its **full** cross-product of
     choices as an N-D **total-cost tensor**.
  2. `pq`: a priority queue whose priority is each tree's **next available** total cost.

- For each discovered uniform tree, we precompute:
  - `axes`: one **decision axis** per node in the uniform tree:
      * `:op` axis for every internal node: allowed operator rule indices + their costs,
      * `:leaf` axis for every leaf: allowed terminal indices + their costs.
  - `cost_tensor`: an N-D Float64 array whose entry at index `(i₁,…,i_N)` equals the sum
    of the selected atom costs along all axes — hence the **full cross product**.
  - `sorted_costs`: unique, sorted list of total costs present in `cost_tensor`.
  - `next_idx`: a pointer into `sorted_costs` telling PQ what cost comes next for this tree.

Iteration order:
1. Pop `(uh_id, cost)` with the **lowest** `cost` from PQ.
2. Emit **all** concrete programs in that uniform tree that have total `cost`.
3. Advance that tree's `next_idx` and, if more costs remain ≤ `max_cost`, re-enqueue it.
4. Attempt to **combine** the popped tree into allowed nonterminal shapes to create new
   uniform trees; if a new tree's minimum cost ≤ `max_cost`, cache + enqueue it.

This guarantees global non-decreasing cost enumeration (ties allowed).
""" CostBasedBottomUpIterator


"""
    $(TYPEDEF)

Returns the maximum allowed total cost for enumeration.
"""
get_max_cost(iter::CostBasedBottomUpIterator) = iter.max_cost

"""
    $(TYPEDEF)

Defines the cost of a uniform hole as the **minimum** atom cost among its domain mask.
(Used only for scalar measure calculations; the tensor contains the full cross product.)
"""
function get_cost(grammar::AbstractGrammar, uhole::UniformHole)
    return get_cost(grammar.log_probabilities, uhole)
end

"""
    $(TYPEDEF)

Minimum cost among indices selected by `uhole.domain`.
"""
get_cost(costs::Vector{<:Number}, uhole::UniformHole) = minimum(costs[uhole.domain])

"""
    $(TYPEDEF)

The measure for a uniform hole is its **minimum** possible total cost (scalar).
"""
calc_measure(iter::CostBasedBottomUpIterator, uhole::UniformHole) = get_cost(get_grammar(iter.solver), uhole)

"""
    $(TYPEDEF)

The measure limit is `max_cost`.
"""
get_measure_limit(iter::CostBasedBottomUpIterator) = get_max_cost(iter)

"""
    calc_measure(iter::CostBasedBottomUpIterator, comb::CombineAddress) -> Float64

A CombineAddress measure is `op_cost + sum(child_costs)`, where `child_costs` are taken
from the addresses' measures. This is only used for pruning during combination.
"""
function calc_measure(iter::CostBasedBottomUpIterator, comb::CombineAddress)
    op_cost = get_cost(get_grammar(iter.solver).log_probabilities, get_operator(comb))
    child_cost_sum = sum(get_measure.(get_children(comb)))
    return op_cost + child_cost_sum
end

"""
    Axis

A decision axis for the cross product of a uniform tree.

Fields:
- `path::Tuple{Vararg{Int}}` : path from the tree root to this node; the root path is `()`.
- `options::Vector{Int}` : grammar indices allowed along this axis.
- `costs::Vector{Float64}` : atom costs corresponding 1-to-1 with `options`.
"""
struct Axis
    path::Tuple{Vararg{Int}}
    options::Vector{Int}
    costs::Vector{Float64}
end

"""
    UniformTreeEntry

A cached, fully-factorized representation of a discovered uniform tree.

Fields:
- `hole::UniformHole` : the uniform tree (shape + children uniform trees).
- `axes::Vector{Axis}` : one axis per decision (operators and leaves) in **fixed order**.
- `cost_tensor::AbstractArray{Float64}` : N-D total-cost tensor of the full cross product.
- `sorted_costs::Vector{Float64}` : unique sorted list of all total costs in `cost_tensor`.
- `next_idx::Int` : pointer into `sorted_costs` (what to offer next to the PQ).
- `rtype::Symbol` : cached return type of the uniform tree (grammar type symbol).
"""
struct UniformTreeEntry
    hole::UniformHole
    axes::Vector{Axis}
    cost_tensor::AbstractArray{Float64}
    sorted_costs::Vector{Float64}
    next_idx::Int
    rtype::Symbol
end

"""
    CostBank

The bank for the cost-based iterator:

- `uh_index::Dict{Int,UniformTreeEntry}` : discovered uniform trees by ID.
- `pq::PriorityQueue{Int,Float64}` : maps `uh_id → next_total_cost` to explore next.
- `next_id::Base.RefValue{Int}` : monotonically increasing ID source.
- `cost_horizon`: the highest cost that has been fully drained (sealed).
- `active_band`: the current cost layer being drained (all PQ items with this priority).
"""
mutable struct CostBank
    uh_index::Dict{Int,UniformTreeEntry}
    pq::PriorityQueue{Int, Float64}
    next_id::Base.RefValue{Int}
    cost_horizon::Float64                    # highest sealed cost
    active_band::Float64                     # cost currently draining (NaN if none)
end

"""
Create an empty bank.
"""
CostBank() = CostBank(
    Dict{Int,UniformTreeEntry}(),
    PriorityQueue{Int,Float64}(),
    Ref(1),
    -Inf,                                     # cost_horizon
    NaN                                      # active_band
)


"""
Access the iterator bank.
"""
get_bank(iter::CostBasedBottomUpIterator) = iter.bank

_pq_max(bank::CostBank) = isempty(bank.pq) ? Inf : maximum(values(bank.pq))

"""
Returns max(cost_horizon, active_band (if set))
"""
function _floor(bank::CostBank)
    isfinite(bank.active_band) ? max(bank.cost_horizon, bank.active_band) : bank.cost_horizon
end

"""
Find first index in sorted_costs with cost >= floor
"""
function _next_idx_from_floor(sorted_costs::Vector{Float64}, floor_cost::Float64)
    searchsortedfirst(sorted_costs, floor_cost)
end

"""
Budget cap for generating new parent shapes this round = min(max cost seen on the frontier, measure_limit); if PQ empty, use measure_limit.
"""
function _budget_cap(iter::CostBasedBottomUpIterator) 
    bank   = get_bank(iter)
    limit  = get_measure_limit(iter)
    pqmax  = _pq_max(bank)
    if isfinite(pqmax)
        min(limit, pqmax)
    else
        limit
    end
end


"""
Group entries by return type for quick lookup during combination
"""
function entries_by_type(bank::CostBank)
    bytype = Dict{Symbol, Vector{UniformTreeEntry}}()
    for (_, ent) in bank.uh_index
        push!(get!(bytype, ent.rtype, UniformTreeEntry[]), ent)
    end
    return bytype
end


"""
    build_axes(grammar, hole; path=()) -> Vector{Axis}

Collect the **decision axes** for the full cross product of `hole`.

- For every leaf: add a `:leaf` axis with all admissible terminal indices and costs.
- For every internal node: add an `:op` axis with all admissible operator indices and costs.
- Recurse into children, extending `path` by child position.

Axes order is deterministic (preorder: node, then its children), and defines the tensor axes.
"""
function build_axes(grammar::AbstractGrammar, hole::UniformHole; path::Tuple{Vararg{Int}}=())
    axes = Axis[]

    if isempty(hole.children)
        term_inds = findall(hole.domain)
        term_costs = Float64.(grammar.log_probabilities[term_inds])
        push!(axes, Axis(path, term_inds, term_costs))
        return axes
    end

    op_inds = findall(hole.domain)
    op_costs = Float64.(grammar.log_probabilities[op_inds])
    push!(axes, Axis(path, op_inds, op_costs))

    @inbounds for (j, ch) in pairs(hole.children)
        child_path = (path..., j)
        append!(axes, build_axes(grammar, ch; path=child_path))
    end
    return axes
end

"""
    build_cost_tensor(axes) -> AbstractArray{Float64}

Given `axes`, produce an N-D tensor `T` whose entry at a Cartesian index `(i₁,…,i_N)`
equals `sum_k axes[k].costs[i_k]`. Implemented by summing N broadcasted vectors, one per axis.
"""
function build_cost_tensor(axes::Vector{Axis})
    N = length(axes)
    dims = ntuple(k -> length(axes[k].options), N)
    T = zeros(Float64, dims...)

    for k in 1:N
        v = axes[k].costs
        shp = ntuple(i -> i == k ? length(v) : 1, N)
        Vk = reshape(v, shp)
        T .+= Vk
    end

    return T
end

"Unique, sorted list of all total costs in a tensor."
unique_sorted_costs(T::AbstractArray{<:Real}) = sort!(unique!(collect(vec(T))))

"""
    build_cost_cross_product(grammar, hole)
        -> (axes, cost_tensor, sorted_costs)

Build the full cross-product for `hole`:

- `axes` defines each decision dimension (operators & leaves).
- `cost_tensor` is an N-D array of total costs (sum over selected axis costs).
- `sorted_costs` lists all distinct totals in ascending order.
"""
function build_cost_cross_product(grammar::AbstractGrammar, hole::UniformHole)
    axes = build_axes(grammar, hole)
    T = build_cost_tensor(axes)
    return axes, T, unique_sorted_costs(T)
end

"""
Approximation tolerance for matching floating-point totals.
"""
cost_match_atol(::CostBasedBottomUpIterator) = 1e-6

"""
    $(TYPEDEF)

Return all Cartesian indices in `ent.cost_tensor` whose value ≈ `total` (within `atol`).
"""
function indices_at_cost(iter::CostBasedBottomUpIterator,
                         ent::UniformTreeEntry,
                         total::Float64)
    atol = cost_match_atol(iter)
    T = ent.cost_tensor
    return findall(x -> isapprox(x, total; atol=atol, rtol=0.0), T)
end

# convert to Vector of ints explictly, due to empty tuples
_pathvec(path::Tuple{Vararg{Int}}) = collect(Int64, path)


"""
    materialize_one_program(iter, ent, idx_tuple) -> RuleNode

Create a `UniformSolver` for `ent.hole`, fix all operator/leaf decisions using
`remove_all_but!` (based on `idx_tuple` into `ent.cost_tensor`), and return the
unique concrete tree by calling `next_solution!(UniformIterator(...))`.
"""
function materialize_one_program(iter::CostBasedBottomUpIterator,
                                 ent::UniformTreeEntry,
                                 idx_tuple::NTuple{N,Int}) where {N}
    @assert N == length(ent.axes)
    grammar = get_grammar(iter.solver)
    usolver = UniformSolver(grammar, ent.hole, with_statistics=get_solver(iter).statistics)

    @inbounds for k in 1:N
        ax       = ent.axes[k]
        rule_idx = ax.options[idx_tuple[k]]


        @show usolver.tree
        @show _pathvec(ax.path)
        @show rule_idx


        remove_all_but!(usolver, _pathvec(ax.path), rule_idx)  # Vector{Int} path
    end

    uiter   = UniformIterator(usolver, iter)

    sol = next_solution!(uiter)
    sol === nothing && error("No solution after fixing all axis choices (unexpected).")
    return sol
end

"""
    $(TYPEDEF)

Return all concrete programs in `ent` whose total cost equals `total`, by mapping all
matching tensor indices through `materialize_one_program`.
"""
function concrete_programs_at_cost(iter::CostBasedBottomUpIterator,
                                   ent::UniformTreeEntry,
                                   total::Float64)::Vector{AbstractRuleNode}
    idxs = indices_at_cost(iter, ent, total)
    progs = []
    if isempty(idxs); return progs; end
    @inbounds for CI in idxs
        push!(progs, materialize_one_program(iter, ent, Tuple(CI))) #@TODO programs will change under the hood!
    end
    return progs
end


"""
    CostAccessAddress <: AbstractAddress

Address to a **concrete** program at a particular cost within a specific uniform tree.

Fields:
- `uh_id::Int` : which uniform tree in the bank.
- `cost::Float64` : total cost to select within this tree's tensor.
- `index::I` : 1-based rank within all concrete programs at that cost for the tree.
- `rtype::Symbol` : cached return type for retrieval-time type checking (optional convenience).
"""
struct CostAccessAddress{I<:Integer} <: AbstractAddress
    uh_id::Int
    cost::Float64
    index::I
    rtype::Symbol
end

"Get the measure (cost) of a `CostAccessAddress`."
get_measure(a::CostAccessAddress) = a.cost
"Get the return type of a `CostAccessAddress`."
get_return_type(a::CostAccessAddress) = a.rtype
"Get the concrete index within the cost-slice."
get_index(a::CostAccessAddress) = a.index

"""
    retrieve(iter, a::CostAccessAddress) -> RuleNode

Return the concrete program addressed by `a`.
"""
function retrieve(iter::CostBasedBottomUpIterator, a::CostAccessAddress)
    ent = get_bank(iter).uh_index[a.uh_id]
    progs = concrete_programs_at_cost(iter, ent, a.cost)
    @boundscheck a.index ≤ length(progs) || error("retrieve: index $(a.index) out of bounds at cost=$(a.cost)")
    return progs[a.index]
end

"""
    retrieve(iter, address::CombineAddress) -> UniformHole

Construct a uniform tree by combining child addresses. This is used during **discovery** of
new shapes (not for yielding concrete programs).
"""
function retrieve(iter::CostBasedBottomUpIterator, address::CombineAddress)::UniformHole
    return UniformHole(get_operator(address).domain,
                       [retrieve(iter, a) for a in get_children(address)])
end

"""
    populate_bank!(iter::CostBasedBottomUpIterator) -> Vector{CostAccessAddress}

Initialize the bank with **terminal** uniform trees (one per grammar type with terminals).
For each such tree, build and cache its full cost tensor, and enqueue its **minimum** cost
into the PQ when `≤ max_cost`.

No concrete programs are yielded here; enumeration begins in `iterate` via `combine`.
"""
function populate_bank!(iter::CostBasedBottomUpIterator)
    grammar = get_grammar(iter.solver)
    bank    = get_bank(iter)

    for t in unique(grammar.types)
        term_mask = grammar.isterminal .& grammar.domains[t]
        if any(term_mask)
            uh = UniformHole(term_mask, [])
            axes, T, sorted_costs = build_cost_cross_product(grammar, uh)
            uh_id = (bank.next_id[] += 1) - 1
            bank.uh_index[uh_id] =
                UniformTreeEntry(uh, axes, T, sorted_costs, 1, t)

            # enqueue from the current floor (horizon/band aware)
            floor = isfinite(bank.active_band) ? bank.active_band : -Inf
            i0 = searchsortedfirst(sorted_costs, floor)
            if i0 ≤ length(sorted_costs)
                c0 = sorted_costs[i0]
                if c0 ≤ get_measure_limit(iter)
                    ent = bank.uh_index[uh_id]
                    bank.uh_index[uh_id] =
                        UniformTreeEntry(ent.hole, ent.axes, ent.cost_tensor,
                                         ent.sorted_costs, i0, ent.rtype)
                    enqueue!(bank.pq, uh_id, c0)
                end
            end
        end
    end

    return CostAccessAddress[]
end


"""
    add_to_bank!(iter, uh::UniformHole) -> Bool

Add a newly discovered uniform tree `uh` to the bank by building its cross product tensor.
If its minimum total cost `≤ max_cost`, enqueue it and return `true`; else return `false`.
"""
function add_to_bank!(iter::CostBasedBottomUpIterator, uh::UniformHole)::Bool
    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)

    axes, T, sorted_costs = build_cost_cross_product(grammar, uh)
    rtype = HerbGrammar.return_type(grammar, uh)

    uh_id = (bank.next_id[] += 1) - 1
    bank.uh_index[uh_id] =
        UniformTreeEntry(uh, axes, T, sorted_costs, 1, rtype)

    floor = isfinite(bank.active_band) ? max(bank.cost_horizon, bank.active_band) : bank.cost_horizon
    i0 = searchsortedfirst(sorted_costs, floor)
    if i0 ≤ length(sorted_costs)
        c0 = sorted_costs[i0]
        if c0 ≤ get_measure_limit(iter)
            ent = bank.uh_index[uh_id]
            bank.uh_index[uh_id] =
                UniformTreeEntry(ent.hole, ent.axes, ent.cost_tensor,
                                 ent.sorted_costs, i0, ent.rtype)
            enqueue!(bank.pq, uh_id, c0)
            return true
        end
    end
    return false
end

"""
    combine(iter::CostBasedBottomUpIterator, state) -> (Vector{CostAccessAddress}, state)

Pop the next cheapest **uniform tree slice** `(uh_id, cost)` from PQ and:

1. Return **addresses** for all concrete programs in that tree with total `cost`.
2. Advance that tree's `next_idx`, and if more costs remain ≤ `max_cost`, re-enqueue it.
3. Attempt to **discover parent** uniform trees by placing the popped tree into nonterminal
   rule shapes where all child slots expect its return type. Any newly added parent is cached
   and, if its minimum cost ≤ `max_cost`, enqueued for future expansion.

If the PQ is empty or we exceed `max_cost`, returns `(nothing, nothing)`.
"""
function combine(iter::CostBasedBottomUpIterator, state)
    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)

    isempty(bank.pq) && return (nothing, nothing)

    @show bank.pq

    # Peek/pick next item
    uh_id, cost = dequeue_pair!(bank.pq)
    cost > get_measure_limit(iter) && return (nothing, nothing)

    # Initialize or advance the current band
    if isnan(bank.active_band)
        bank.active_band = cost
    elseif cost > bank.active_band + eps(bank.active_band)  # moved to next band
        bank.cost_horizon = bank.active_band                # seal the old band
        bank.active_band  = cost
    end

    ent = bank.uh_index[uh_id]

    # emit all concrete programs at this popped cost for this tree
    progs = concrete_programs_at_cost(iter, ent, cost)
    out_addrs = [CostAccessAddress(uh_id, cost, i, ent.rtype) for i in 1:length(progs)]

    # advance this tree’s pointer to the next cost >= current band floor
    floor = _floor(bank)
    next_i = ent.next_idx + 1
    while next_i ≤ length(ent.sorted_costs) && ent.sorted_costs[next_i] < floor
        next_i += 1
    end
    if next_i ≤ length(ent.sorted_costs)
        nxt = ent.sorted_costs[next_i]
        bank.uh_index[uh_id] = UniformTreeEntry(ent.hole, ent.axes, ent.cost_tensor, ent.sorted_costs, next_i, ent.rtype)
        if nxt ≤ get_measure_limit(iter)
            enqueue!(bank.pq, uh_id, nxt)
        end
    end

    # discover parents using *combinations* of entries that fit within the budget
    budget = _budget_cap(iter)

    # group entries by return type once
    bytype = Dict{Symbol, Vector{Tuple{Int,UniformTreeEntry}}}()
    for (id, e) in bank.uh_index
        push!(get!(bytype, e.rtype, Tuple{Int,UniformTreeEntry}[]), (id, e))
    end

    terminals = grammar.isterminal
    nonterm   = .~terminals
    shapes    = UniformHole.(partition(Hole(nonterm), grammar), ([],))

    for shape in shapes
        rule_idx = findfirst(shape.domain)
        rule_idx === nothing && continue
        child_types = Tuple(grammar.childtypes[rule_idx])
        n = length(child_types)
        op_min = minimum(grammar.log_probabilities[shape.domain])

        # candidate lists per child slot
        candidate_lists = Vector{Vector{Tuple{Int,UniformTreeEntry}}}(undef, n)
        feasible = true
        @inbounds for i in 1:n
            lst = get(bytype, child_types[i], nothing)
            if lst === nothing || isempty(lst)
                feasible = false; break
            end
            candidate_lists[i] = lst
        end
        feasible || continue

        for child_tuple in Iterators.product(candidate_lists...)
            # lower bound using each child's *current* band floor if within band, else its min
            lb = op_min
            @inbounds for (_id, e) in child_tuple
                # use e.sorted_costs[1] (min) — sufficient for pruning
                lb += e.sorted_costs[1]
            end
            lb ≤ budget || continue

            parent_hole = UniformHole(shape.domain, UniformHole[e.hole for (_id, e) in child_tuple])
            add_to_bank!(iter, parent_hole)  # will skip/enqueue based on horizon/band
        end
    end

    return out_addrs, state
end


"""
    Base.iterate(iter::CostBasedBottomUpIterator)

Seed terminal uniform trees and defer concrete enumeration to the stateful call.
"""
function Base.iterate(iter::CostBasedBottomUpIterator)
    populate_bank!(iter)
    return Base.iterate(iter, nothing)
end

"""
    Base.iterate(iter::CostBasedBottomUpIterator, state)

Call `combine` to pop the next cheapest slice and yield one concrete program
(`RuleNode`) at a time in correct cost order.
"""
function Base.iterate(iter::CostBasedBottomUpIterator, state)
    addrs, st = combine(iter, state)
    if isnothing(addrs) || isempty(addrs)
        return nothing
    end

    queue = Vector{CostAccessAddress}(addrs)
    addr = popfirst!(queue)
    prog = retrieve(iter, addr)
    return prog, queue
end

