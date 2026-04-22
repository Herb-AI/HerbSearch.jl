


"""
    BUBank{P}

A bank that stores programs grouped by return type and integer cost.

`P` is the program type: `UniformHole` for size/depth-based iterators,
`RuleNode` for cost-based iterators.
"""
struct BUBank{P}
    data::Dict{Symbol, Dict{Int, Vector{P}}}

    BUBank{P}() where {P} = new{P}(Dict{Symbol, Dict{Int, Vector{P}}}())
end

"""
    add!(bank::BUBank{P}, type::Symbol, cost::Int, prog::P)

Add `prog` to the bank under the given return `type` and integer `cost`.
"""
function add!(bank::BUBank{P}, type::Symbol, cost::Int, prog::P) where {P}
    by_cost = get!(bank.data, type, Dict{Int, Vector{P}}())
    progs   = get!(by_cost, cost, P[])
    push!(progs, prog)
    return nothing
end

"""
    get_programs(bank::BUBank, type::Symbol, cost::Int) :: Vector{P}

Return all programs in `bank` with return type `type` and cost `cost`.
Returns an empty vector if no such programs exist.
"""
function get_programs(bank::BUBank{P}, type::Symbol, cost::Int)::Vector{P} where {P}
    by_cost = get(bank.data, type, nothing)
    isnothing(by_cost) && return P[]
    return get(by_cost, cost, P[])
end


"""
    get_costs(bank::BUBank, type::Symbol) :: AbstractSet{Int}

Return the set of costs for which `bank` holds at least one program of return
type `type`. Returns an empty set if the type is absent.
"""
function get_costs(bank::BUBank{P}, type::Symbol) where {P}
    by_cost = get(bank.data, type, nothing)
    isnothing(by_cost) && return keys(Dict{Int, Vector{P}}())
    return keys(by_cost)
end

"""
    get_types(bank::BUBank) :: AbstractSet{Symbol}

Return all return types present in `bank`.
"""
function get_types(bank::BUBank)
    return keys(bank.data)
end

"""
    has_programs(bank::BUBank, type::Symbol, cost::Int) :: Bool

Return `true` iff `bank` holds at least one program of return type `type`
and cost `cost`.
"""
function has_programs(bank::BUBank, type::Symbol, cost::Int)::Bool
    by_cost = get(bank.data, type, nothing)
    isnothing(by_cost) && return false
    progs = get(by_cost, cost, nothing)
    isnothing(progs) && return false
    return !isempty(progs)
end


"""
    compositions(n::Int, k::Int)

Return an iterator over all ordered k-tuples of positive integers summing to `n`.
These are the integer compositions of `n` into `k` parts.

The number of results is `C(n-1, k-1)` by a stars-and-bars argument: write `n`
as a row of `n` stars and place `k-1` dividers in the `n-1` gaps between them.
Each choice of `k-1` gaps out of `n-1` available gives a unique composition.

Returns an empty iterator when `n < k` (impossible to have `k` parts each ≥ 1).

# Examples
```julia
collect(compositions(3, 2))  # [(1,2), (2,1)]
collect(compositions(3, 1))  # [(3,)]
collect(compositions(2, 3))  # [] (impossible: 3 parts each ≥ 1 need sum ≥ 3)
```
"""
function compositions(n::Int, k::Int)
    return (
        tuple(v...)
        for v in _compositions(n, k)
    )
end

function _compositions(n::Int, k::Int)::Vector{Vector{Int}}
    k == 1 && return n >= 1 ? [[n]] : Vector{Vector{Int}}()
    result = Vector{Vector{Int}}()
    for first in 1:(n - k + 1)
        for rest in _compositions(n - first, k - 1)
            push!(result, [first; rest])
        end
    end
    return result
end


"""
    program_combinations(bank::BUBank, types, budget::Int)

Return an iterator over all tuples `(p1, …, pk)` such that:
- `pi` is a program in `bank` with return type `types[i]`
- the costs `(c1, …, ck)` of the chosen programs sum to `budget`

Internally enumerates cost distributions via [`compositions`](@ref) and then
takes the cartesian product of the matching programs in the bank. Distributions
where any slot has no programs in the bank are skipped.

Each cost distribution is handled by [`_slots_product`](@ref), which performs one
Dict lookup per slot and returns a single concrete `ProductIterator` type regardless
of whether any slot is empty. This keeps the enclosing `Iterators.flatten` type-stable.
"""
function program_combinations(bank::BUBank, types, budget::Int)
    k = length(types)
    return Iterators.flatten(
        _slots_product(bank, types, costs)
        for costs in compositions(budget, k)
    )
end

"""
    _slots_product(bank, types, costs)

Fetch the program vectors for each slot via [`get_programs`](@ref), short-circuiting
as soon as any slot is empty. Returns an empty `Iterators.product` on the first
empty slot without fetching the remaining ones.

`slots` is pre-filled with `P[]` so that every return path — including early exits
— calls `Iterators.product(slots...)` on a fully-initialised vector. This keeps
the return type a single concrete `ProductIterator` (no union with `Tuple{}`),
making the caller's `Iterators.flatten` type-stable.
"""
function _slots_product(bank::BUBank{P}, types, costs) where {P}
    slots = fill(P[], length(types))
    for i in eachindex(types)
        s = get_programs(bank, types[i], costs[i])
        isempty(s) && return Iterators.product(slots...)
        slots[i] = s
    end
    return Iterators.product(slots...)
end


"""
    AbstractBUSIterator

Abstract type for the new bottom-up iterators.

Concrete subtypes must have the fields:
- `grammar::AbstractGrammar`
- `start_symbol::Symbol`
- `max_cost::Int`
- `program_to_outputs::Union{Nothing,Function}` — `nothing` disables OE

Behaviour can be customised by overriding any of the three extension methods:
- [`node_cost`](@ref) — cost of a single operator node (default: `1`)
- [`make_bank`](@ref) — bank structure (default: `BUBank{RuleNode}()`)
- [`grow`](@ref)      — how new programs are constructed (default: compositions + cartesian product)
"""
abstract type AbstractBUSIterator end

"""
    node_cost(iter::AbstractBUSIterator, op::Int) :: Int

Return the cost of applying operator (rule index) `op` as a single node.
The default returns `1` (size-based enumeration).
Override to implement cost-based enumeration.
"""
node_cost(::AbstractBUSIterator, ::Int) = 1
node_cost(::AbstractBUSIterator, ::RuleNode) = 1

"""
    make_bank(iter::AbstractBUSIterator)

Return a fresh empty bank for `iter`.
The default returns `BUBank{RuleNode}()`.
Override to use a different bank structure.
"""
make_bank(::AbstractBUSIterator) = BUBank{RuleNode}()

"""
    assemble(op::Int, children) :: RuleNode

Construct a `RuleNode` for rule `op` with the given `children`.
"""
assemble(op::Int, children) = RuleNode(op, collect(children))

"""
    assemble(prog::RuleNode, children) :: RuleNode

Fill the holes in `prog` with `children` in depth-first order and return
the resulting complete program. Holes (any `AbstractHole` subtype) are
replaced one by one as they are encountered during a left-to-right
depth-first traversal.
"""
function assemble(prog::RuleNode, children)
    iter = Iterators.Stateful(children)
    return _fill_holes(prog, iter)
end

function _fill_holes(node::RuleNode, iter)
    new_children = Vector{AbstractRuleNode}(undef, length(node.children))
    for (i, child) in enumerate(node.children)
        new_children[i] = child isa AbstractHole ? popfirst!(iter) : _fill_holes(child, iter)
    end
    return RuleNode(node.ind, new_children)
end

"""
    grow(iter::AbstractBUSIterator, level::Int, grammar::AbstractGrammar, bank::BUBank, ops::Vector{Int})

Return an iterator of `(program, type)` pairs — all programs of cost `level`
constructable from programs already in `bank` by applying a single non-terminal
rule.

`ops` is the pre-computed list of non-terminal rule indices (see [`nonterminals`](@ref)).
Callers should compute this once and reuse it across levels; `grow` itself does not
call `nonterminals` so that the allocation is not repeated on every level.

For each non-terminal operator `op`, the child budget is `level - node_cost(iter, op)`.
[`program_combinations`](@ref) enumerates all child tuples whose costs sum to
that budget, and [`assemble`](@ref) constructs the resulting program.
"""
function grow(iter::AbstractBUSIterator, level::Int, grammar::AbstractGrammar, bank::BUBank, ops::Vector{Int})
    return Iterators.flatten(
        _grow_op(iter, level, grammar, bank, op)
        for op in ops
    )
end

function _grow_op(iter, level, grammar, bank, op)
    budget = level - node_cost(iter, op)
    return (
        (assemble(op, children), grammar.types[op])
        for children in program_combinations(bank, grammar.childtypes[op], budget)
    )
end


# ──── CostBUSIterator ────────────────────────────────────────────────────────

"""
    _hash_outputs(outputs) → UInt64

Fold all per-example outputs into a single `UInt64` signature by chaining
Julia's built-in `hash` function over each output value.

Using a single scalar instead of a `Vector{UInt64}` makes `Set` membership
checks O(1) rather than O(n) in the number of examples, and avoids allocating
a signature vector on every OE probe. The 64-bit hash space makes collisions
negligible in practice (probability ≈ n²/2⁶⁵ for n programs).
"""
function _hash_outputs(outputs)::UInt64
    h = HASH_SEED
    for o in outputs
        h = hash(o, h)
    end
    return h
end

"""
    is_observationally_equivalent!(seen, type, prog, eval_fn) → Bool

Return `true` if `prog` produces the same outputs as some already-seen program
of the same `type` under `eval_fn`. If not, record `prog`'s output signature in
`seen` and return `false`.

When `eval_fn` is `nothing`, OE pruning is disabled and the function always
returns `false`.
"""
function is_observationally_equivalent!(
    seen::Dict{Symbol, Set{UInt64}},
    type::Symbol,
    prog::RuleNode,
    eval_fn
)
    isnothing(eval_fn) && return false
    sig = _hash_outputs(eval_fn(prog))
    type_seen = get!(seen, type, Set{UInt64}())
    sig ∈ type_seen && return true
    push!(type_seen, sig)
    return false
end


"""
    CostBUSIterator

A bottom-up iterator that enumerates `RuleNode` programs in order of increasing
integer cost, where `cost(prog) = sum of rule_costs[rule_idx]` over all nodes.

Programs are yielded only when their return type equals `start_symbol`.
An optional `program_to_outputs` function enables observational-equivalence
pruning: programs with identical output signatures are discarded.

# Fields
- `grammar`            — the grammar to search over
- `start_symbol`       — the return type of programs to yield
- `max_cost`           — upper bound on program cost (inclusive)
- `rule_costs`         — integer cost for each rule index
- `program_to_outputs` — optional `RuleNode → Vector` used for OE pruning
  (`nothing` disables OE)
"""
struct CostBUSIterator{G<:AbstractGrammar, F} <: AbstractBUSIterator
    grammar::G
    start_symbol::Symbol
    max_cost::Int
    rule_costs::Vector{Int}
    program_to_outputs::F
end

CostBUSIterator(grammar, start_symbol, max_cost, rule_costs) =
    CostBUSIterator(grammar, start_symbol, max_cost, rule_costs, nothing)

node_cost(iter::CostBUSIterator, op::Int) = iter.rule_costs[op]
node_cost(iter::CostBUSIterator, prog::RuleNode) = iter.rule_costs[prog.ind]

Base.IteratorSize(::Type{<:CostBUSIterator}) = Base.SizeUnknown()


"""
    BUSState{B}

Iteration state for any [`AbstractBUSIterator`](@ref).

- `bank`        — programs accumulated so far, grouped by type and cost
- `seen`        — OE output signatures seen so far, grouped by type
- `ops`         — rule indices of all non-terminal rules (constant; cached here to
                  avoid recomputing on every `iterate` call)
- `level`       — cost level currently being yielded
- `yield_index` — index of the next program to yield within `bank[start_symbol][level]`

The bank type `B` is determined by [`make_bank`](@ref).
"""
struct BUSState{B}
    bank::B
    seen::Dict{Symbol, Set{UInt64}}
    ops::Vector{Int}
    level::Int
    yield_index::Int
end

# Keep the old name as an alias so existing code continues to work.
const CostBUSState = BUSState{BUBank{RuleNode}}

function Base.iterate(iter::AbstractBUSIterator)
    bank    = make_bank(iter)
    seen    = Dict{Symbol, Set{UInt64}}()
    grammar = iter.grammar
    ops     = findall(.!grammar.isterminal)   # computed once for the lifetime of the iterator

    # Seed the bank with all terminal programs.
    for rule_idx in eachindex(grammar.isterminal)
        grammar.isterminal[rule_idx] || continue
        prog = RuleNode(rule_idx)
        type = grammar.types[rule_idx]
        cost = node_cost(iter, rule_idx)
        if !is_observationally_equivalent!(seen, type, prog, iter.program_to_outputs)
            add!(bank, type, cost, prog)
        end
    end

    # Start at level 0; _next_bus will immediately advance to level 1.
    return _next_bus(iter, BUSState(bank, seen, ops, 0, 1))
end

function Base.iterate(iter::AbstractBUSIterator, state::BUSState)
    return _next_bus(iter, state)
end

function _satisfies_constraints(grammar, prog)
    isempty(grammar.constraints) && return true
    all(HerbConstraints.check_tree(c, prog) for c in grammar.constraints)
end

function _next_bus(iter::AbstractBUSIterator, state::BUSState)
    bank    = state.bank
    seen    = state.seen
    ops     = state.ops
    level   = state.level
    yi      = state.yield_index
    grammar = iter.grammar

    while true
        progs = get_programs(bank, iter.start_symbol, level)
        while yi <= length(progs)
            prog = progs[yi]
            yi += 1
            if _satisfies_constraints(grammar, prog)
                return prog, BUSState(bank, seen, ops, level, yi)
            end
        end

        # Nothing left to yield at this level — advance.
        level += 1
        level > iter.max_cost && return nothing
        yi = 1

        # Grow all programs of cost `level` and add them to the bank.
        # Children always have cost < level (node_cost ≥ 1), so the bank
        # is complete for all needed children before we start growing.
        # Constraint-violating programs are still banked — they can be
        # used as sub-expressions in larger programs.
        for (prog, type) in grow(iter, level, grammar, bank, ops)
            if !is_observationally_equivalent!(seen, type, prog, iter.program_to_outputs)
                add!(bank, type, level, prog)
            end
        end
    end
end
