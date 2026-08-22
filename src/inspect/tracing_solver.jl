"""
    TraceEvent

One recorded action of the constraint solver.

- `kind`: `:propagate`, `:post`, `:manipulate`, `:load_state`, `:restore` or `:new_state`
- `solver`: `:generic` or `:uniform`, the kind of solver the event happened on
- `name`: the function/constraint name, e.g. `"LocalForbidden"` or `"remove_all_but!"`
- `detail`: a human readable description of the arguments
- `path`: the location in the tree the event applies to (constraint path / manipulated path)
- `index`: chronological position of the event (events are *completed* out of order,
   because an enclosing event finishes after the events it contains)
- `parent`: index of the enclosing event, or `0` for a top level event
- `before`/`after`: tree snapshots taken just before and just after the event
"""
mutable struct TraceEvent
    index::Int
    kind::Symbol
    solver::Symbol
    name::String
    detail::String
    path::Vector{Int}
    parent::Int
    depth::Int
    step::Int
    before::Union{NodeSnapshot,Nothing}
    after::Union{NodeSnapshot,Nothing}
    feasible_before::Bool
    feasible_after::Bool
    changes::Vector{NodeChange}
end

"""
    Trace

Collects [`TraceEvent`](@ref)s. A single `Trace` is shared by the generic solver of an
iterator and by every uniform solver that is spawned during the search, so the events of
the whole search end up in one chronologically ordered list.

- `sink`: called with every event as soon as it is complete. This is the hook the lazy
  [`Inspection`](@ref) uses: its sink blocks until a consumer asks for the next event, which
  is what suspends the search half way through a fix point.
- `step`: the number of the program the search is currently working towards; stamped onto
  every event so a front end can group them.
- `logging`: also emit every event as a `@debug` message in the `:herb_inspect` group.
"""
mutable struct Trace
    events::Vector{TraceEvent}
    stack::Vector{Int}
    enabled::Bool
    max_events::Int
    sink::Any
    step::Int
    logging::Bool
end

Trace(; max_events::Int=100_000, sink=nothing, logging::Bool=false) =
    Trace(TraceEvent[], Int[], true, max_events, sink, 0, logging)

Base.length(trace::Trace) = length(trace.events)

"""
    TracingSolver{S} <: Solver

A transparent proxy around a [`GenericSolver`](@ref) or [`UniformSolver`](@ref) that records
everything the solver does into a [`Trace`](@ref).

The wrapper forwards every field access and every solver API call to the wrapped solver, so
constraint propagators, tree manipulations and iterators behave exactly as they would
without it. The only difference is that

- `fix_point!` propagates the scheduled constraints one at a time and snapshots the tree
  around every `propagate!` call, and
- tree manipulations, `post!`s and state changes are recorded.

This is what makes the inspector work without changing the solver implementation.
"""
struct TracingSolver{S<:HerbConstraints.Solver} <: HerbConstraints.Solver
    inner::S
    trace::Trace
end

_inner(t::TracingSolver) = getfield(t, :inner)
_trace(t::TracingSolver) = getfield(t, :trace)

solver_kind(::TracingSolver{<:GenericSolver}) = :generic
solver_kind(::TracingSolver{<:UniformSolver}) = :uniform
solver_kind(::TracingSolver) = :other

# The proxy is transparent: `solver.tree`, `solver.schedule`, `solver.max_size = 5`, ...
Base.getproperty(t::TracingSolver, name::Symbol) =
    (name === :inner || name === :trace) ? getfield(t, name) : getproperty(_inner(t), name)
Base.setproperty!(t::TracingSolver, name::Symbol, x) = setproperty!(_inner(t), name, x)
Base.propertynames(t::TracingSolver) = propertynames(_inner(t))
Base.show(io::IO, t::TracingSolver) = print(io, "TracingSolver(", _inner(t), ")")

# ---------------------------------------------------------------------------------------
# Recording helpers
# ---------------------------------------------------------------------------------------

"""
    current_tree(t::TracingSolver)

The current tree of the wrapped solver, or `nothing` if the solver has no state yet
(this happens while a `GenericSolver` is being initialised).
"""
function current_tree(t::TracingSolver{<:GenericSolver})
    inner = _inner(t)
    isnothing(inner.state) && return nothing
    return inner.state.tree
end
current_tree(t::TracingSolver) = HerbConstraints.get_tree(_inner(t))

_feasible(t::TracingSolver{<:GenericSolver}) =
    isnothing(_inner(t).state) ? true : _inner(t).state.isfeasible
_feasible(t::TracingSolver) = HerbConstraints.isfeasible(_inner(t))

function _open_event!(t::TracingSolver, kind::Symbol, name, detail, path::Vector{Int})
    trace = _trace(t)
    parent = isempty(trace.stack) ? 0 : last(trace.stack)
    idx = length(trace.events) + 1
    event = TraceEvent(idx, kind, solver_kind(t), string(name), string(detail), path, parent,
        length(trace.stack), trace.step, take_snapshot(current_tree(t)), nothing,
        _feasible(t), true, NodeChange[])
    push!(trace.events, event)
    push!(trace.stack, idx)
    return idx
end

function _close_event!(t::TracingSolver, idx::Int)
    trace = _trace(t)
    @assert last(trace.stack) == idx
    pop!(trace.stack)
    event = trace.events[idx]
    event.after = take_snapshot(current_tree(t))
    event.feasible_after = _feasible(t)
    event.changes = diff_snapshots(event.before, event.after)
    trace.logging && _log_event(event)
    # Handing the finished event to the sink is what makes the search lazy: the sink of a
    # live `Inspection` blocks until someone asks for the next event.
    isnothing(trace.sink) || trace.sink(event)
    return event
end

"""
    _log_event(event)

Emit `event` as a `@debug` message tagged with `_group = :herb_inspect`, so that it can be
filtered out of the log stream (with `LoggingExtras.EarlyFilteredLogger`, for example).
"""
function _log_event(event::TraceEvent)
    @debug "$(event.kind) $(event.name)" _group = :herb_inspect index = event.index step = event.step kind = event.kind name = event.name detail = event.detail path = event.path solver = event.solver changes = event.changes feasible = event.feasible_after
    return nothing
end

"""
    record!(f, t, kind, name, detail, path)

Run `f()` while recording a [`TraceEvent`](@ref) around it.
"""
function record!(f, t::TracingSolver, kind::Symbol, name, detail, path::Vector{Int})
    trace = _trace(t)
    if !trace.enabled || length(trace.events) >= trace.max_events
        return f()
    end
    idx = _open_event!(t, kind, name, detail, path)
    try
        return f()
    finally
        _close_event!(t, idx)
    end
end

_constraint_path(c) = hasproperty(c, :path) ? collect(Int, c.path) : Int[]
_shortname(x) = string(nameof(typeof(x)))

function _describe(name::Symbol, args::Tuple)
    parts = String[]
    for a ∈ args
        if a isa Vector{Int}
            push!(parts, "[" * join(a, ", ") * "]")
        elseif a isa BitVector
            push!(parts, "{" * join(findall(a), ", ") * "}")
        elseif a isa AbstractRuleNode
            push!(parts, string(a))
        else
            push!(parts, string(a))
        end
    end
    return string(name) * "(" * join(parts, ", ") * ")"
end

_path_arg(args::Tuple) = isempty(args) ? Int[] : (first(args) isa Vector{Int} ? copy(first(args)) : Int[])

# ---------------------------------------------------------------------------------------
# The traced fix point: this is where constraint propagation becomes observable
# ---------------------------------------------------------------------------------------

"""
    fix_point!(t::TracingSolver)

Same fix point loop as `HerbConstraints.fix_point!`, but every `propagate!` call is wrapped
in a [`TraceEvent`](@ref). Nested fix point calls made by the wrapped solver are suppressed
(exactly as they are without tracing), so the whole schedule is drained by this loop.
"""
function HerbConstraints.fix_point!(t::TracingSolver)
    inner = _inner(t)
    if inner.fix_point_running
        return
    end
    inner.fix_point_running = true
    try
        while !isempty(inner.schedule)
            if !HerbConstraints.isfeasible(inner)
                # an inconsistency was found, stop propagating constraints and return
                empty!(inner.schedule)
                break
            end
            (constraint, _) = popfirst!(inner.schedule)
            record!(t, :propagate, _shortname(constraint), string(constraint),
                _constraint_path(constraint)) do
                HerbConstraints.propagate!(t, constraint)
            end
        end
    finally
        inner.fix_point_running = false
    end
end

# ---------------------------------------------------------------------------------------
# Traced entry points
#
# Each of these records the manipulation, delegates to the wrapped solver with the wrapped
# solver's own fix point suppressed, and then runs the *traced* fix point instead.
# The observable behaviour is identical, because the suppressed call would have been a
# no-op re-entrant `fix_point!` anyway.
# ---------------------------------------------------------------------------------------

for fname ∈ (:remove!, :remove_all_but!, :remove_above!, :remove_below!,
    :substitute!, :remove_node!, :simplify_hole!)
    @eval function HerbConstraints.$fname(t::TracingSolver, args...; kwargs...)
        record!(t, :manipulate, $(QuoteNode(fname)), _describe($(QuoteNode(fname)), args),
            _path_arg(args)) do
            inner = _inner(t)
            was_running = inner.fix_point_running
            inner.fix_point_running = true
            try
                HerbConstraints.$fname(inner, args...; kwargs...)
            finally
                inner.fix_point_running = was_running
            end
            HerbConstraints.fix_point!(t)
        end
        return nothing
    end
end

# Re-implementation of `new_state!`, so that the grammar constraints that are posted while
# a new partial program is loaded are recorded individually.
function HerbConstraints.new_state!(t::TracingSolver{<:GenericSolver}, tree::AbstractRuleNode)
    record!(t, :new_state, "new_state!", "load a partial program into the solver", Int[]) do
        inner = _inner(t)
        empty!(inner.schedule)
        inner.state = SolverState(tree)
        function _dfs_simplify(node::AbstractRuleNode, path::Vector{Int})
            if node isa AbstractHole
                HerbConstraints.simplify_hole!(t, path)
            end
            for (i, childnode) ∈ enumerate(_children(node))
                _dfs_simplify(childnode, push!(copy(path), i))
            end
        end
        _dfs_simplify(tree, Vector{Int}())
        # the tree may have been replaced by the simplifications above
        HerbConstraints.notify_new_nodes(t, HerbConstraints.get_tree(inner), Vector{Int}())
        HerbConstraints.fix_point!(t)
    end
    return nothing
end

function HerbConstraints.post!(t::TracingSolver, constraint::HerbConstraints.AbstractLocalConstraint)
    record!(t, :post, _shortname(constraint), string(constraint),
        _constraint_path(constraint)) do
        _post_forwarded!(t, constraint)
    end
    return nothing
end

# Re-implementation of `post!` that keeps the wrapper in play, so that the *initial*
# propagation of a freshly posted constraint is traced as well.
function _post_forwarded!(t::TracingSolver{<:GenericSolver}, constraint)
    inner = _inner(t)
    HerbConstraints.isfeasible(inner) || return
    push!(HerbConstraints.get_state(inner).active_constraints, constraint)
    temp = inner.fix_point_running
    inner.fix_point_running = true
    try
        HerbConstraints.propagate!(t, constraint)
    finally
        inner.fix_point_running = temp
    end
end

function _post_forwarded!(t::TracingSolver{<:UniformSolver}, constraint)
    inner = _inner(t)
    HerbConstraints.isfeasible(inner) || return
    temp = inner.fix_point_running
    inner.fix_point_running = true
    try
        HerbConstraints.propagate!(t, constraint)
    finally
        inner.fix_point_running = temp
    end
    if constraint ∈ inner.canceledconstraints
        delete!(inner.canceledconstraints, constraint)
        return
    end
    if !(constraint ∈ keys(inner.isactive))
        inner.isactive[constraint] = StateInt(inner.sm, 0)
    end
    set_value!(inner.isactive[constraint], 1)
end

# `notify_new_nodes` has to stay in the wrapper so that the `on_new_node` callbacks (and
# therefore the `post!`s they perform) are traced.
function HerbConstraints.notify_new_nodes(t::TracingSolver{<:GenericSolver},
    node::AbstractRuleNode, path::Vector{Int})
    HerbConstraints.notify_new_node(t, path)
    for (i, childnode) ∈ enumerate(_children(node))
        HerbConstraints.notify_new_nodes(t, childnode, push!(copy(path), i))
    end
end

function HerbConstraints.notify_new_nodes(t::TracingSolver{<:UniformSolver},
    node::AbstractRuleNode, path::Vector{Int})
    inner = _inner(t)
    inner.path_to_node[path] = node
    inner.node_to_path[node] = path
    for (i, childnode) ∈ enumerate(_children(node))
        HerbConstraints.notify_new_nodes(t, childnode, push!(copy(path), i))
    end
    for c ∈ HerbConstraints.get_grammar(inner).constraints
        HerbConstraints.on_new_node(t, c, path)
    end
end

function HerbConstraints.notify_new_node(t::TracingSolver{<:GenericSolver}, path::Vector{Int})
    HerbConstraints.isfeasible(_inner(t)) || return
    for c ∈ HerbConstraints.get_grammar(_inner(t)).constraints
        HerbConstraints.on_new_node(t, c, path)
    end
end

# ---------------------------------------------------------------------------------------
# Traced state changes (these are how iterators move through the search tree)
# ---------------------------------------------------------------------------------------

function HerbConstraints.load_state!(t::TracingSolver{<:GenericSolver}, state::SolverState)
    record!(t, :load_state, "load_state!", "restore a previously saved solver state", Int[]) do
        HerbConstraints.load_state!(_inner(t), state)
    end
    return nothing
end

function HerbConstraints.restore!(t::TracingSolver{<:UniformSolver})
    record!(t, :restore, "restore!", "backtrack to the last saved state", Int[]) do
        HerbConstraints.restore!(_inner(t))
    end
    return nothing
end

# ---------------------------------------------------------------------------------------
# Plain forwarding (no tracing needed)
# ---------------------------------------------------------------------------------------

for fname ∈ (:get_tree, :get_grammar, :get_starting_symbol, :get_state, :get_max_depth,
    :get_max_size, :get_tree_size, :isfeasible, :save_state!, :get_nodes)
    @eval HerbConstraints.$fname(t::TracingSolver) = HerbConstraints.$fname(_inner(t))
end

HerbConstraints.set_infeasible!(t::TracingSolver) = HerbConstraints.set_infeasible!(_inner(t))
HerbConstraints.deactivate!(t::TracingSolver, c::HerbConstraints.AbstractLocalConstraint) =
    HerbConstraints.deactivate!(_inner(t), c)
HerbConstraints.notify_tree_manipulation(t::TracingSolver, path::Vector{Int}) =
    HerbConstraints.notify_tree_manipulation(_inner(t), path)
HerbConstraints.schedule!(t::TracingSolver, c::HerbConstraints.AbstractLocalConstraint) =
    HerbConstraints.schedule!(_inner(t), c)
# `shouldschedule` is deliberately *not* forwarded: it is only ever called from
# `notify_tree_manipulation`, which already runs on the wrapped solver. Defining it here
# would be ambiguous with the per-constraint methods in HerbConstraints.
HerbConstraints.get_hole_at_location(t::TracingSolver, path::Vector{Int}) =
    HerbConstraints.get_hole_at_location(_inner(t), path)
HerbCore.get_node_at_location(t::TracingSolver, path::Vector{Int}) =
    get_node_at_location(_inner(t), path)
HerbCore.get_path(t::TracingSolver, node::AbstractRuleNode) = get_path(_inner(t), node)

# ---------------------------------------------------------------------------------------
# Dispatch bridges
#
# A handful of `propagate!`/`on_new_node` methods dispatch on the *concrete* solver type
# (`GenericSolver` / `UniformSolver`) instead of on `Solver`. For those, a wrapper argument
# would be a `MethodError`. The methods below are generated from the method tables so that
# every constraint type keeps working:
#
# - if the implementation accepts `::Solver`, the wrapper is passed through (`invoke`), so
#   everything the propagator does stays traced,
# - otherwise the call is forwarded to the wrapped solver (that single propagation is then
#   recorded as a whole, but its individual tree manipulations are not).
# ---------------------------------------------------------------------------------------

const _BRIDGED = Set{Tuple{Symbol,Any}}()

"""
    _install_dispatch_bridges!()

Generate the `propagate!`/`on_new_node` methods that accept a [`TracingSolver`](@ref).
Called once when `HerbSearch` is loaded and again whenever an inspection starts, so that
constraints defined after loading are picked up as well.
"""
function _install_dispatch_bridges!()
    for (fn, nargs) ∈ ((:propagate!, 3), (:on_new_node, 4))
        f = getproperty(HerbConstraints, fn)
        # per constraint type: does an implementation exist that accepts an abstract `Solver`?
        generic = Dict{Any,Bool}()
        for m ∈ methods(f)
            params = Base.unwrap_unionall(m.sig).parameters
            length(params) == nargs || continue
            S, C = params[2], params[3]
            (C isa DataType && C !== Any) || continue
            (S === HerbConstraints.Solver || S === GenericSolver || S === UniformSolver) || continue
            generic[C] = get(generic, C, false) || (S === HerbConstraints.Solver)
        end
        for (C, takes_wrapper) ∈ generic
            key = (fn, C)
            key ∈ _BRIDGED && continue
            push!(_BRIDGED, key)
            if fn === :propagate!
                if takes_wrapper
                    @eval HerbConstraints.propagate!(t::TracingSolver, c::$C) =
                        invoke(HerbConstraints.propagate!, Tuple{HerbConstraints.Solver,$C}, t, c)
                else
                    @eval HerbConstraints.propagate!(t::TracingSolver, c::$C) =
                        HerbConstraints.propagate!(_inner(t), c)
                end
            else
                if takes_wrapper
                    @eval HerbConstraints.on_new_node(t::TracingSolver, c::$C, path::Vector{Int}) =
                        invoke(HerbConstraints.on_new_node, Tuple{HerbConstraints.Solver,$C,Vector{Int}}, t, c, path)
                else
                    @eval HerbConstraints.on_new_node(t::TracingSolver, c::$C, path::Vector{Int}) =
                        HerbConstraints.on_new_node(_inner(t), c, path)
                end
            end
        end
    end
    return nothing
end

# ---------------------------------------------------------------------------------------
# Traced solver construction
#
# The stock constructors already propagate constraints before we could wrap them, so the
# inspector builds the solvers itself (using the plain struct constructors) and then runs
# the initialisation through the wrapper.
# ---------------------------------------------------------------------------------------

"""
    tracing_generic_solver(grammar, init; trace, max_size, max_depth)

Build a [`GenericSolver`](@ref) wrapped in a [`TracingSolver`](@ref), so that even the
initial propagation on the start symbol / initial node is recorded.
"""
function tracing_generic_solver(grammar::AbstractGrammar, sym::Symbol; kwargs...)
    return tracing_generic_solver(grammar, Hole(get_domain(grammar, sym)); kwargs...)
end

function tracing_generic_solver(grammar::AbstractGrammar, init_node::AbstractRuleNode;
    trace::Trace=Trace(), max_size::Int=typemax(Int), max_depth::Int=typemax(Int))
    inner = GenericSolver(grammar, nothing,
        PriorityQueue{HerbConstraints.AbstractLocalConstraint,Int}(),
        nothing, false, max_size, max_depth)
    t = TracingSolver(inner, trace)
    HerbConstraints.new_state!(t, init_node)
    return t
end

"""
    tracing_uniform_solver(grammar, tree; trace, with_statistics)

Build a [`UniformSolver`](@ref) wrapped in a [`TracingSolver`](@ref). Mirrors the stock
`UniformSolver` constructor, but routes the initial propagation through the wrapper.
"""
function tracing_uniform_solver(grammar::AbstractGrammar, fixed_shaped_tree::AbstractRuleNode;
    trace::Trace=Trace(), with_statistics=nothing)
    @assert !contains_nonuniform_hole(fixed_shaped_tree) "$(fixed_shaped_tree) contains non-uniform holes"
    sm = HerbConstraints.StateManager()
    tree = StateHole(sm, fixed_shaped_tree)
    inner = UniformSolver(grammar, sm, tree,
        Dict{Vector{Int},AbstractRuleNode}(),
        Dict{AbstractRuleNode,Vector{Int}}(),
        Dict{HerbConstraints.AbstractLocalConstraint,StateInt}(),
        Set{HerbConstraints.AbstractLocalConstraint}(),
        true,
        PriorityQueue{HerbConstraints.AbstractLocalConstraint,Int}(),
        false,
        with_statistics isa TimerOutput ? with_statistics : nothing)
    t = TracingSolver(inner, trace)
    HerbConstraints.notify_new_nodes(t, tree, Vector{Int}())
    HerbConstraints.fix_point!(t)
    return t
end

# Hook into the top down iterators: when the outer solver is traced, the uniform solver it
# spawns for a uniform tree is traced too (sharing the same `Trace`).
function _make_uniform_iterator(::HerbStyle, solver::TracingSolver, iter::TopDownIterator)
    uniform_solver = tracing_uniform_solver(get_grammar(solver), get_tree(solver);
        trace=_trace(solver), with_statistics=solver.statistics)
    return UniformIterator(uniform_solver, iter)
end

_install_dispatch_bridges!()
