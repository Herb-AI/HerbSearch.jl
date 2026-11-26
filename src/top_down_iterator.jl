"""
    mutable struct TopDownIterator <: ProgramIterator 

Enumerates a context-free grammar starting at [`Symbol`](@ref) `sym` with respect to the grammar up to a given depth and a given size. 
The exploration is done using the given priority function for derivations, and the expand function for discovered nodes.
Concrete iterators may overload the following methods:
- priority_function
- derivation_heuristic
- hole_heuristic
"""
abstract type TopDownIterator <: ProgramIterator end

"""
    ConstraintStyle

Abstract type representing the family of constraint styles present in Herb.

There are currently two styles, namely:

- [`HerbStyle`](@ref): The default, this corresponds to iterators that enforce
    constraints using the propagation implemented in `HerbConstraints`. 
- [`ASPStyle`](@ref): Corresponds to iterators that enforce constraints using ASP via Clingo.

See [`constraint_style`](@ref).
"""
abstract type ConstraintStyle end
struct ASPStyle <: ConstraintStyle end
struct HerbStyle <: ConstraintStyle end

"""
    constraint_style(it)

Get the constraint style of an iterator.
"""
constraint_style(::ProgramIterator) = HerbStyle()

"""
    priority_function(::TopDownIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}, isrequeued::Bool)

Assigns a priority value to a `tree` that needs to be considered later in the search. Trees with the lowest priority value are considered first.

- ``: The first argument is a dispatch argument and is only used to dispatch to the correct priority function
- `g`: The grammar used for enumeration
- `tree`: The tree that is about to be stored in the priority queue
- `parent_value`: The priority value of the parent [`SolverState`](@ref) (`0` for the root)
- `isrequeued`: The same tree shape will be requeued. The next time this tree shape is considered, the `UniformSolver` will produce the next complete program deriving from this shape.

Entries with equal priority values are considered in the order they were added to the queue (first in, first out).
The returned value must be of the iterator's [`priority_type`](@ref).

The default (for a `TopDownIterator` that doesn't define its own) counts the branching steps: `parent_value + 1`,
and a requeued shape keeps `parent_value`. [`AbstractBFSIterator`](@ref)s use [`bfs_priority`](@ref) instead.
"""
function priority_function(
    ::TopDownIterator,
    g::AbstractGrammar,
    tree::AbstractRuleNode,
    parent_value,
    isrequeued::Bool
)
    if isrequeued
        return parent_value
    end
    return parent_value + 1
end

"""
    priority_type(iter::TopDownIterator)

The type of the priority values that [`priority_function`](@ref) returns for `iter`; the priority queue of the
iteration is typed with it. The default is `Union{Real, Tuple{Vararg{Real}}}`. [`BFSIterator`](@ref) and
[`BFSASPIterator`](@ref) use [`BFSPriority`](@ref). Other [`AbstractBFSIterator`](@ref)s use the union of both, so
that a subtype may override `priority_function` with numbers.

An iterator whose `priority_function` returns another type must define `priority_type` too.
"""
priority_type(::TopDownIterator) = Union{Real,Tuple{Vararg{Real}}}

"""
    function derivation_heuristic(::TopDownIterator, indices::Vector{Int})

Returns a sorted sublist of the `indices`, based on which rules are most promising to fill a hole.
The underlying solver can change the order within a Hole's domain. We sort the domain to make the enumeration order explicit and more predictable. 
"""
function derivation_heuristic(::TopDownIterator, indices::Vector{Int})
    return sort(indices)
end

"""
    hole_heuristic(::TopDownIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason, HoleReference}

Defines a heuristic over variable shaped holes. Returns a [`HoleReference`](@ref) once a hole is found.
"""
function hole_heuristic(::TopDownIterator, node::AbstractRuleNode, max_depth::Int)::Union{ExpandFailureReason,HoleReference}
    return heuristic_leftmost(node, max_depth)
end

Base.@doc """
    @programiterator RandomIterator() <: TopDownIterator

Iterates trees in the grammar in a random order.
""" RandomIterator
@programiterator RandomIterator() <: TopDownIterator

"""
    priority_function(::RandomIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}, isrequeued::Bool)

Assigns a random priority to each state.
"""
function priority_function(
    ::RandomIterator,
    ::AbstractGrammar,
    ::AbstractRuleNode,
    ::Union{Real,Tuple{Vararg{Real}}},
    ::Bool
)
    Random.rand()
end

"""
    function derivation_heuristic(::RandomIterator, indices::Vector{Int})

Randomly shuffles the rules.
"""
function derivation_heuristic(::RandomIterator, indices::Vector{Int})
    return Random.shuffle!(indices)
end

"""
    AbstractBFSIterator <: TopDownIterator

This is the supertype for all breadth-first search iterators. It inherits all stop-criteria and traversal mechanisms from [`TopDownIterator`](@ref).
Its priority is [`bfs_priority`](@ref): programs come out in non-decreasing size, in an order that doesn't depend on the constraints.
"""
abstract type AbstractBFSIterator <: TopDownIterator end

"""
    BFSPriority

The priority of a partial program in an [`AbstractBFSIterator`](@ref) (see [`bfs_priority`](@ref)): the pre-order
sequence `ids` of the shape ids of the tree's nodes. Priorities are ordered by the tree's size (`length(ids)`)
first, then lexicographically by `ids`.
"""
struct BFSPriority
    ids::Vector{Int}
end

function Base.isless(a::BFSPriority, b::BFSPriority)
    la, lb = length(a.ids), length(b.ids)
    la == lb || return la < lb
    return isless(a.ids, b.ids)
end
Base.:(==)(a::BFSPriority, b::BFSPriority) = a.ids == b.ids
Base.hash(a::BFSPriority, h::UInt) = hash(a.ids, hash(:BFSPriority, h))

function _push_shape_ids!(ids::Vector{Int}, grammar::AbstractGrammar, node::AbstractRuleNode)
    if node isa AbstractHole && !(node isa AbstractUniformHole)
        # a variable-shaped hole: no shape yet, and no children
        push!(ids, 0)
        return ids
    end
    rule = node isa AbstractUniformHole ? findfirst(node.domain) : get_rule(node)
    push!(ids, shape_id(grammar, rule))
    for child ∈ node.children
        _push_shape_ids!(ids, grammar, child)
    end
    return ids
end

"""
    bfs_priority(grammar::AbstractGrammar, tree::AbstractRuleNode)::BFSPriority

The priority of the partial program `tree` in an [`AbstractBFSIterator`](@ref): the pair `(size, ids)`, ordered by
`size` first and then lexicographically by `ids` (a [`BFSPriority`](@ref)).

- `size` is the number of nodes, counting every variable-shaped [`Hole`](@ref) as 1 (a lower bound on the size of
  any program the tree can become). `size == length(ids)`.
- `ids` is the pre-order sequence of the `HerbConstraints.shape_id`s of the nodes: the rule's for a `RuleNode`, the one of
  the domain's rules for a [`UniformHole`](@ref) (a single shape), and 0 for a variable-shaped `Hole` (which has no
  children).

The priority depends on the tree and the grammar only, so the same partial program gets the same priority under any
constraints. The `ids` determine the shape of the tree, so different shapes never tie. Filling a hole adds nodes, or
replaces a 0 by a positive id at the same size, so a tree's priority is always greater than its parent's. Hence the
programs come out in non-decreasing size, shape by shape, and the programs of a shape in the lexicographic order of
its [`UniformIterator`](@ref).

The whole tree is scanned on every call: propagation can change holes anywhere in the tree, so the priority can't be
derived from the parent's.
"""
function bfs_priority(grammar::AbstractGrammar, tree::AbstractRuleNode)::BFSPriority
    return BFSPriority(_push_shape_ids!(Int[], grammar, tree))
end

"""
    priority_function(::AbstractBFSIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value, isrequeued::Bool)

The [`bfs_priority`](@ref) of `tree`. A requeued shape keeps its priority (`parent_value`). That priority is below
every other entry's, so a shape is enumerated completely before the next one.
"""
function priority_function(
    ::AbstractBFSIterator,
    g::AbstractGrammar,
    tree::AbstractRuleNode,
    parent_value,
    isrequeued::Bool
)
    if isrequeued
        return parent_value
    end
    return bfs_priority(g, tree)
end

priority_type(::AbstractBFSIterator) = Union{Real,Tuple{Vararg{Real}},BFSPriority}

Base.@doc """
    @programiterator BFSIterator() <: AbstractBFSIterator

Creates a breadth-first search iterator for traversing given a grammar, starting from the given symbol.
The iterator returns trees in the grammar in non-decreasing order of size: shape by shape in the order of
[`bfs_priority`](@ref), and the programs of one shape in lexicographic order (holes in pre-order, rules ascending).

The order doesn't depend on the constraints: with constraints, the iterator returns the programs it returns without
them, in the same order, minus the programs that the constraints remove.
""" BFSIterator
@programiterator BFSIterator() <: AbstractBFSIterator
priority_type(::BFSIterator) = BFSPriority

Base.@doc """
    @programiterator BFSASPIterator() <: AbstractBFSIterator

Creates a breadth-first search iterator for traversing given a grammar,
starting from the given symbol. The iterator returns trees in the grammar in
non-decreasing order of size, in the same order as [`BFSIterator`](@ref).

Constraints on uniform trees are enforced in ASP, making use of Clingo.
Behavior should otherwise match that of [`AbstractBFSIterator`](@ref)s.
""" BFSASPIterator
@programiterator BFSASPIterator() <: AbstractBFSIterator
constraint_style(::BFSASPIterator) = ASPStyle()
priority_type(::BFSASPIterator) = BFSPriority

"""
    AbstractDFSIterator <: TopDownIterator

This is the supertype for all depth-first search iterators. It inherits all stop-criteria and from [`TopDownIterator`](@ref), but the traversal mechanism is 
implemented to perform a depth-first search.
"""
abstract type AbstractDFSIterator <: TopDownIterator end


"""
    priority_function(::AbstractDFSIterator, g::AbstractGrammar, tree::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}, isrequeued::Bool)

Assigns priority such that the search tree is traversed like in a DFS manner: a tree's priority is its depth in the
search tree, negated (`parent_value - 1`). A requeued shape gets `parent_value - 1` too, so a shape is enumerated
completely before its siblings (from HerbSearch PR #146).
"""
function priority_function(
    ::AbstractDFSIterator,
    ::AbstractGrammar,
    ::AbstractRuleNode,
    parent_value::Union{Real,Tuple{Vararg{Real}}},
    isrequeued::Bool
)
    return parent_value - 1
end

Base.@doc """
    @programiterator DFSIterator() <: AbstractDFSIterator

Creates a depth-first search iterator for traversing a given a grammar, starting from a given symbol.
The iterator returns the trees in the pre-order of the search tree: at each variable-shaped hole, the shapes are
tried in the order of `HerbConstraints.partition` (by their smallest rule in the grammar), and the programs of one
shape come out consecutively, in lexicographic order (holes in pre-order, rules ascending).

The order doesn't depend on the constraints: with constraints, the iterator returns the programs it returns without
them, in the same order, minus the programs that the constraints remove.
""" DFSIterator
@programiterator DFSIterator() <: AbstractDFSIterator

Base.@doc """
    @programiterator DFSASPIterator() <: AbstractDFSIterator

Creates a depth-first search iterator for traversing given a grammar,
starting from the given symbol. The iterator returns trees in the same order as
[`DFSIterator`](@ref).

Constraints on uniform trees are enforced in ASP, making use of Clingo.
Behavior should otherwise match that of [`AbstractDFSIterator`](@ref)s.
""" DFSASPIterator
@programiterator DFSASPIterator() <: AbstractDFSIterator
constraint_style(::DFSASPIterator) = ASPStyle()

Base.@doc """
    @programiterator MLFSIterator() <: TopDownIterator

Iterator that enumerates expressions in the grammar in decreasing order of probability (Only use this iterator with probabilistic grammars). Inherits all stop-criteria from TopDownIterator.
""" MLFSIterator
@programiterator MLFSIterator() <: TopDownIterator

"""
    priority_function(::MLFSIterator, grammar::AbstractGrammar, current_program::AbstractRuleNode, parent_value::Union{Real, Tuple{Vararg{Real}}}, isrequeued::Bool)

Calculates the priority function of the `MLFSIterator`. The priority value of a tree is then the max_rulenode_log_probability within the represented uniform tree.
The value is negated as lower priority values are popped earlier.
"""
function priority_function(
    ::MLFSIterator,
    grammar::AbstractGrammar,
    current_program::AbstractRuleNode,
    parent_value::Union{Real,Tuple{Vararg{Real}}},
    isrequeued::Bool
)
    -max_rulenode_log_probability(current_program, grammar)
end

"""
    derivation_heuristic(iter::MLFSIterator, domain::Vector{Int})

Defines `derivation_heuristic` for the iterator type `MLFSIterator`. 
Sorts the indices within a domain, that is grammar rules, by decreasing log_probabilities. 
    
This will invert the enumeration order if probabilities are equal.
"""
function derivation_heuristic(iter::MLFSIterator, domain::Vector{Int})
    log_probs = get_grammar(iter).log_probabilities
    return sort(domain, by=i -> log_probs[i], rev=true) # have highest log_probability first
end

"""
    ExpandFailureReason

Abstract type representing the different reasons why expanding a partial tree failed. 

Currently, there are two possible causes of the expansion failing:

- [`LimitReached`](@ref): The depth limit or the size limit of the partial tree would 
   be violated by the expansion
- [`AlreadyComplete`](@ref): There is no hole left in the tree, so nothing can be 
   expanded.
"""
abstract type ExpandFailureReason end
struct LimitReached <: ExpandFailureReason end
struct AlreadyComplete <: ExpandFailureReason end


"""
    function Base.collect(iter::TopDownIterator)

Return an array of all programs in the TopDownIterator. 
!!! warning
    This requires deepcopying programs from type StateHole to type RuleNode.
    If it is not needed to save all programs, iterate over the iterator manually.
"""
function Base.collect(iter::TopDownIterator)
    @warn "Collecting all programs of a TopDownIterator requires freeze_state"
    programs = Vector{RuleNode}()
    for program ∈ iter
        push!(programs, freeze_state(program))
    end
    return programs
end

"""
    QueueKey{P}

The key of an entry in the priority queue of a [`TopDownIterator`](@ref): the entry's `priority` (of the
iterator's [`priority_type`](@ref)) and its insertion `order`. Keys are ordered by `priority`, and entries with equal
priorities by `order`, so ties are broken first in, first out (`DataStructures.PriorityQueue` is a binary heap,
which doesn't break ties in insertion order by itself).
"""
struct QueueKey{P}
    priority::P
    order::Int
end

function Base.isless(a::QueueKey, b::QueueKey)
    isless(a.priority, b.priority) && return true
    isless(b.priority, a.priority) && return false
    return a.order < b.order
end

"""
    mutable struct TopDownState{Q, U, P}

The iteration state of a [`TopDownIterator`](@ref).

- `pq`: the priority queue of `SolverState`s (variable-shaped trees) and uniform iterators (of type `U`, fixed-shaped trees), keyed by [`QueueKey`](@ref)`{P}`.
- `counter`: the number of entries pushed so far (the insertion order of the next entry).
- `current`: the uniform iterator being enumerated outside the queue, or `nothing` (see [`requeue_fast_path`](@ref)).
- `current_priority`: the priority of `current`.
"""
mutable struct TopDownState{Q<:PriorityQueue,U<:AbstractUniformIterator,P}
    pq::Q
    counter::Int
    current::Union{U,Nothing}
    current_priority::Union{P,Nothing}
end

function _new_state(::Type{U}, ::Type{P}) where {U,P}
    pq = PriorityQueue{Union{SolverState,U},QueueKey{P}}()
    return TopDownState{typeof(pq),U,P}(pq, 0, nothing, nothing)
end

_uniform_iterator_type(::HerbStyle) = UniformIterator
_uniform_iterator_type(::ASPStyle) = UniformASPIterator

function _init_state(iter::TopDownIterator)
    return _new_state(_uniform_iterator_type(constraint_style(iter)), priority_type(iter))
end

"""
    requeue_fast_path(iter::TopDownIterator)::Bool

Whether the iteration may keep a requeued uniform iterator out of the priority queue (default: `true`).

After each program, the uniform iterator of its shape is requeued with the priority that [`priority_function`](@ref)
gives it (`isrequeued = true`). If that priority is strictly below the priority of every entry in the queue, the
shape would be popped straight back. With the fast path, it is kept as the state's current shape instead, which saves
a push and a pop per program and doesn't change the order. The priorities of [`AbstractBFSIterator`](@ref) and
[`AbstractDFSIterator`](@ref) always take the fast path.
"""
requeue_fast_path(::TopDownIterator) = true

function _enqueue!(st::TopDownState{Q,U,P}, item, priority) where {Q,U,P}
    st.counter += 1
    push!(st.pq, item => QueueKey{P}(priority, st.counter))
    return st
end

function _requeue!(st::TopDownState, iter::TopDownIterator, uniform_iterator::AbstractUniformIterator, priority)
    if requeue_fast_path(iter) && (isempty(st.pq) || isless(priority, first(st.pq)[2].priority))
        # `uniform_iterator` is the queue's strict minimum: it would be popped next, so keep it out of the queue
        st.current = uniform_iterator
        st.current_priority = priority
    else
        _enqueue!(st, uniform_iterator, priority)
    end
    return st
end

"""
    Base.iterate(iter::TopDownIterator)

Describes the iteration for a given [`TopDownIterator`](@ref) over the grammar. The iteration constructs a [`PriorityQueue`](@ref) first and then prunes it propagating the active constraints. Recursively returns the result for the priority queue.
"""
function Base.iterate(iter::TopDownIterator)
    # Priority queue with `SolverState`s (for variable shaped trees) and `UniformIterator`s (for fixed shaped trees)
    st = _init_state(iter)

    solver = get_solver(iter)

    if isfeasible(solver)
        _enqueue!(st, get_state(solver), priority_function(iter, get_grammar(solver), get_tree(solver), 0, false))
    end
    return _find_next_complete_tree(get_solver(iter), st, iter)
end

"""
    Base.iterate(iter::TopDownIterator, st::TopDownState)

Describes the iteration for a given [`TopDownIterator`](@ref) and its [`TopDownState`](@ref): the next program of the
current shape, if any, or else the next program obtained from the priority queue.
"""
function Base.iterate(iter::TopDownIterator, st::TopDownState)
    @timeit_debug get_solver(iter).statistics "#CompleteTrees (by UniformSolver)" begin end
    solver = get_solver(iter)
    if !isnothing(st.current)
        uniform_iterator, priority_value = st.current, st.current_priority
        st.current = nothing
        st.current_priority = nothing
        solution_or_nothing = _find_next_complete_tree(solver, st, iter, uniform_iterator, priority_value)
        if !isnothing(solution_or_nothing)
            return solution_or_nothing
        end
    end
    return _find_next_complete_tree(solver, st, iter)
end

"""
    _find_next_complete_tree(solver::Solver, st::TopDownState, iter::TopDownIterator)::Union{Tuple{AbstractRuleNode, TopDownState}, Nothing}

Takes the iteration state and returns the smallest AST from the grammar it can obtain from the queue or by (repeatedly) expanding trees that are in the queue.
Returns `nothing` if there are no trees left within the depth limit.
"""
function _find_next_complete_tree(
    solver::Solver,
    st::TopDownState,
    iter::TopDownIterator
)
    while length(st.pq) ≠ 0
        (item, key) = popfirst!(st.pq)
        solution_or_nothing = _find_next_complete_tree(solver, st, iter, item, key.priority)
        if !isnothing(solution_or_nothing)
            return solution_or_nothing
        end
    end
    return nothing
end

function _find_next_complete_tree(
    solver::Solver,
    st::TopDownState,
    iter::TopDownIterator,
    item::AbstractUniformIterator,
    priority_value
)
    #the item is a fixed shaped solver, we should get the next solution and re-enqueue it with a new priority value
    uniform_iterator = item
    solution = next_solution!(uniform_iterator)
    if !isnothing(solution)
        _requeue!(st, iter, uniform_iterator, priority_function(iter, get_grammar(solver), solution, priority_value, true))
        return (solution, st)
    end
end

function _find_next_complete_tree(
    solver::Solver,
    st::TopDownState,
    iter::TopDownIterator,
    item::SolverState,
    priority_value
)
    #the item is a solver state, we should find a variable shaped hole to branch on
    state = item
    load_state!(solver, state)

    hole_res = hole_heuristic(iter, get_tree(solver), get_max_depth(solver))
    return _decide_hole(solver, st, iter, item, priority_value, hole_res)
end

function _decide_hole(
    solver::Solver,
    st::TopDownState,
    iter::TopDownIterator,
    ::SolverState,
    priority_value,
    ::AlreadyComplete
)
    @timeit_debug get_solver(iter).statistics "#FixedShapedTrees" begin end
    # Always use the Uniform Solver
    uniform_iterator = _make_uniform_iterator(solver, iter)
    solution = next_solution!(uniform_iterator)
    if !isnothing(solution)
        _requeue!(st, iter, uniform_iterator, priority_function(iter, get_grammar(solver), solution, priority_value, true))
        return (solution, st)
    end
end

function _make_uniform_iterator(solver::Solver, iter::TopDownIterator)
    return _make_uniform_iterator(constraint_style(iter), solver, iter)
end

function _make_uniform_iterator(::HerbStyle, solver::Solver, iter::TopDownIterator)
    uniform_solver = UniformSolver(get_grammar(solver), get_tree(solver), with_statistics=solver.statistics)
    return UniformIterator(uniform_solver, iter)
end

function _make_uniform_iterator(::ASPStyle, solver::Solver, iter::TopDownIterator)
    uniform_solver = HerbConstraints.ASPSolver(get_grammar(solver), get_tree(solver), with_statistics=solver.statistics)
    return UniformASPIterator(uniform_solver, iter)
end

function _decide_hole(
    ::Solver,
    ::TopDownState,
    ::TopDownIterator,
    ::SolverState,
    ::Any,
    ::LimitReached
)
    # The maximum depth is reached
    return nothing
end

function _decide_hole(
    solver::Solver,
    st::TopDownState,
    iter::TopDownIterator,
    ::SolverState,
    priority_value,
    hole_res::HoleReference
)
    # Variable Shaped Hole was found
    (; hole, path) = hole_res

    partitioned_domains = partition(hole, get_grammar(solver))
    number_of_domains = length(partitioned_domains)
    for (i, domain) ∈ enumerate(partitioned_domains)
        if i < number_of_domains
            state = save_state!(solver)
        end
        @assert isfeasible(solver) "Attempting to expand an infeasible tree: $(get_tree(solver))"
        remove_all_but!(solver, path, domain)
        if isfeasible(solver)
            _enqueue!(st, get_state(solver), priority_function(iter, get_grammar(solver), get_tree(solver), priority_value, false))
        end
        if i < number_of_domains
            load_state!(solver, state)
        end
    end
end
