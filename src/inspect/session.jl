"""
    QueueEntry

One item of a search queue, frozen for display.
"""
struct QueueEntry
    kind::String
    priority::String
    tree::Union{NodeSnapshot,Nothing}
    feasible::Bool
    info::String
end

"""
    SearchStep

One program emitted by an iterator, together with the state of the search queue right after
it was emitted. The [`TraceEvent`](@ref)s that led to it carry the same `index` in their
`step` field.
"""
struct SearchStep
    index::Int
    program::Union{NodeSnapshot,Nothing}
    expr::String
    queue::Vector{QueueEntry}
end

struct _InspectionClosed <: Exception end

"""
    Inspection

A lazily driven recording of a program iterator.

The search runs in its own task and is *pull based*: it advances only as far as somebody
asks it to, and suspends again — possibly half way through a fix point — until the next
request. Nothing is enumerated up front, so an inspection of an unbounded search is fine.

- `steps`: the programs pulled so far
- `events`: the solver events pulled so far, **in completion order** (an enclosing event
  finishes after the events it contains). Use `chronological(insp)` for `index` order.
- `finished`: the iterator is exhausted (or the inspection was closed)

Drive it with [`advance!`](@ref), subscribe with [`on_update!`](@ref), release it with
`close`.
"""
mutable struct Inspection
    title::String
    grammar::AbstractGrammar
    iterator::Union{ProgramIterator,Nothing}
    trace::Trace
    steps::Vector{SearchStep}
    events::Vector{TraceEvent}
    channel::Union{Channel{Any},Nothing}
    finished::Bool
    listeners::Vector{Any}
    lock::ReentrantLock
    file::String
    server::Any
end

function Base.show(io::IO, insp::Inspection)
    print(io, "Inspection(\"", insp.title, "\", ", length(insp.steps), " program(s), ",
        length(insp.events), " solver event(s)")
    insp.finished ? print(io, ", finished") : print(io, ", suspended")
    isnothing(insp.server) || print(io, ", ", insp.server.url)
    isempty(insp.file) || print(io, ", ", insp.file)
    print(io, ")")
end

"""
    chronological(insp::Inspection)

The events pulled so far, ordered by when they *started* rather than by when they finished.
"""
chronological(insp::Inspection) = sort(insp.events, by=e -> e.index)

# ---------------------------------------------------------------------------------------
# Freezing the things the front ends display
# ---------------------------------------------------------------------------------------

_queue_of(pq::PriorityQueue) = pq
_queue_of(state::Tuple) = length(state) == 2 && state[2] isa PriorityQueue ? state[2] : nothing
_queue_of(::Any) = nothing

_tree_of_item(item::SolverState) = item.tree
_tree_of_item(item::AbstractUniformIterator) = get_tree(get_solver(item))
_tree_of_item(::Any) = nothing

_feasible_of_item(item::SolverState) = item.isfeasible
_feasible_of_item(item::AbstractUniformIterator) = isfeasible(get_solver(item))
_feasible_of_item(::Any) = true

_info_of_item(item::SolverState) = "$(length(item.active_constraints)) active local constraint(s)"
_info_of_item(item::AbstractUniformIterator) = "$(item.nsolutions) solution(s) emitted so far"
_info_of_item(::Any) = ""

function _snapshot_queue(pq)
    entries = QueueEntry[]
    isnothing(pq) && return entries
    items = collect(pq)
    try
        sort!(items, by=last)
    catch
        # priorities of mixed types cannot be sorted; keep the heap order
    end
    for (item, priority) ∈ items
        tree = _tree_of_item(item)
        push!(entries, QueueEntry(
            string(nameof(typeof(item))),
            string(priority),
            isnothing(tree) ? nothing : take_snapshot(tree),
            _feasible_of_item(item),
            _info_of_item(item)))
    end
    return entries
end

function _program_expr(program, grammar::AbstractGrammar)
    try
        return string(rulenode2expr(freeze_state(program), grammar))
    catch
        return string(program)
    end
end

# ---------------------------------------------------------------------------------------
# The search task
# ---------------------------------------------------------------------------------------

# The sink is called from deep inside the solver, every time an event completes. Putting the
# event on an unbuffered channel blocks the search until a consumer takes it: that is the
# whole laziness mechanism.
function _make_sink(insp::Inspection, ch::Channel)
    return function (event::TraceEvent)
        if !isopen(ch)
            # the consumer went away; stop recording and unwind the search task
            insp.trace.enabled = false
            insp.trace.sink = nothing
            throw(_InspectionClosed())
        end
        put!(ch, event)
        return nothing
    end
end

function _search_task(insp::Inspection, ch::Channel)
    iter = insp.iterator
    trace = insp.trace
    grammar = insp.grammar
    trace.sink = _make_sink(insp, ch)
    try
        trace.step = 1
        next = iterate(iter)
        while !isnothing(next)
            (program, state) = next
            put!(ch, SearchStep(trace.step, take_snapshot(program),
                _program_expr(program, grammar), _snapshot_queue(_queue_of(state))))
            trace.step += 1
            next = iterate(iter, state)
        end
    catch err
        # a closed channel simply means nobody is interested anymore
        (err isa _InspectionClosed || (err isa InvalidStateException && err.state === :closed)) || rethrow()
    finally
        trace.sink = nothing
    end
    return nothing
end

"""
    Inspection(iter::ProgramIterator; title, buffer, spawn)

Start a lazy inspection of `iter`. Nothing is enumerated until [`advance!`](@ref) is called.

- `buffer`: how many items the search may compute ahead of the consumer (default `0`,
  i.e. strictly lazy)
- `spawn`: run the search on another thread. This is safe — the solver is only ever touched
  by the search task, consumers see immutable snapshots — but it is only useful together
  with `buffer > 0`, and it makes the recording non-deterministic in time. Off by default.
"""
function Inspection(iter::ProgramIterator; title::AbstractString="",
    buffer::Int=0, spawn::Bool=false)
    solver = get_solver(iter)
    trace = solver isa TracingSolver ? _trace(solver) : Trace()
    grammar = get_grammar(iter)
    name = isempty(title) ? string(nameof(typeof(iter))) : String(title)

    insp = Inspection(name, grammar, iter, trace, SearchStep[], TraceEvent[], nothing,
        false, Any[], ReentrantLock(), "", nothing)
    # events recorded while the solver was built are already complete; they belong to step 0
    append!(insp.events, trace.events)
    insp.channel = Channel{Any}(ch -> _search_task(insp, ch), buffer; spawn=spawn)
    return insp
end

# ---------------------------------------------------------------------------------------
# Driving the search
# ---------------------------------------------------------------------------------------

_accept!(insp::Inspection, event::TraceEvent) = push!(insp.events, event)
_accept!(insp::Inspection, step::SearchStep) = push!(insp.steps, step)
_accept!(::Inspection, ::Any) = nothing

function _take_next!(insp::Inspection)
    try
        return take!(insp.channel)
    catch err
        if err isa InvalidStateException && err.state === :closed
            insp.finished = true
            return nothing
        end
        insp.finished = true
        rethrow()
    end
end

"""
    advance!(insp::Inspection; programs=0, events=0)
    advance!(insp::Inspection, programs::Int)

Let the search run until `programs` more programs have been emitted **and** `events` more
solver events have been recorded, whichever takes longer. Returns `insp`.

`advance!(insp; events=1)` resumes the search for exactly one propagation and suspends it
again, even if that happens in the middle of a fix point.
"""
function advance!(insp::Inspection; programs::Int=0, events::Int=0)
    lock(insp.lock) do
        isnothing(insp.channel) && return
        target_steps = length(insp.steps) + max(programs, 0)
        target_events = length(insp.events) + max(events, 0)
        while !insp.finished &&
              (length(insp.steps) < target_steps || length(insp.events) < target_events)
            item = _take_next!(insp)
            isnothing(item) && break
            _accept!(insp, item)
        end
    end
    _notify!(insp)
    return insp
end

advance!(insp::Inspection, programs::Int) = advance!(insp; programs=programs)

"""
    run_to_end!(insp::Inspection; max_programs=1000)

Keep pulling until the iterator is exhausted or `max_programs` have been emitted.
"""
function run_to_end!(insp::Inspection; max_programs::Int=1000)
    while !insp.finished && length(insp.steps) < max_programs
        before = (length(insp.steps), length(insp.events))
        advance!(insp; programs=1)
        (length(insp.steps), length(insp.events)) == before && break
    end
    return insp
end

"""
    on_update!(f, insp::Inspection)

Register `f(insp)`, called after every [`advance!`](@ref). This is the hook a reactive front
end needs; with `Observables` loaded, [`observe`](@ref) wraps it for you.
"""
function on_update!(f, insp::Inspection)
    push!(insp.listeners, f)
    return f
end

function _notify!(insp::Inspection)
    for f ∈ insp.listeners
        try
            f(insp)
        catch err
            @warn "an inspection listener failed" exception = (err, catch_backtrace())
        end
    end
    return nothing
end

function Base.close(insp::Inspection)
    isnothing(insp.server) || close(insp.server)
    insp.server = nothing
    if !isnothing(insp.channel)
        insp.trace.sink = nothing
        insp.trace.enabled = false
        close(insp.channel)
        insp.channel = nothing
    end
    insp.finished = true
    return insp
end

"""
    observe(insp::Inspection)

Available when `Observables` is loaded. Returns a named tuple of `Observable`s
(`steps`, `events`, `latest`) that update on every [`advance!`](@ref).
"""
function observe end

# ---------------------------------------------------------------------------------------
# Front door
# ---------------------------------------------------------------------------------------

"""
    record_inspection(iter::ProgramIterator; max_programs, title) -> Inspection

Eagerly record at most `max_programs` programs of `iter` and return the finished
[`Inspection`](@ref). Convenience wrapper around [`Inspection`](@ref) + [`run_to_end!`](@ref)
for scripts and tests; the interactive path is lazy.
"""
function record_inspection(iter::ProgramIterator; max_programs::Int=25,
    title::AbstractString="")
    insp = Inspection(iter; title=title)
    run_to_end!(insp; max_programs=max_programs)
    return insp
end

"""
    inspect(iter::ProgramIterator; kwargs...) -> Inspection

Record `iter` and open an interactive visualisation of it.

# Keyword arguments
- `live`: serve the page from Julia and let it pull the search forward on demand
  (default `true`). With `live=false` a static, self-contained page is written instead,
  which requires enumerating `max_programs` programs up front.
- `prefetch`: how many programs to compute before the page is opened (default `1`). This is
  not a ceiling: a live inspection can be pulled arbitrarily far afterwards.
- `max_programs`: how many programs to enumerate. **Only used when `live=false`**
  (default `25`); a live inspection ignores it.
- `output`: where to write the static page (default: a temporary file)
- `open_browser`: open the page in the default browser (default `true`)
- `logging`: also emit every solver event as a `@debug` message in the `:herb_inspect`
  group, so it can be filtered/routed (e.g. with `LoggingExtras`)
- `title`: title of the page

Prefer [`@inspect`](@ref), which also traces the construction of the solver.
"""
function inspect(iter::ProgramIterator; live::Bool=true, prefetch::Int=1,
    max_programs::Int=25, output::AbstractString="", open_browser::Bool=true,
    logging::Bool=false, title::AbstractString="", buffer::Int=0, spawn::Bool=false)

    solver = get_solver(iter)
    solver isa TracingSolver && (_trace(solver).logging = logging)
    insp = Inspection(iter; title=title, buffer=buffer, spawn=spawn)

    if live
        advance!(insp; programs=max(prefetch, 0))
        serve!(insp)
        open_browser && _open_in_browser(insp.server.url)
        isempty(output) || write_html(insp, output)
    else
        run_to_end!(insp; max_programs=max_programs)
        file = isempty(output) ? joinpath(tempdir(), "herb_inspect_$(getpid()).html") : String(output)
        write_html(insp, file)
        open_browser && _open_in_browser(file)
    end
    return insp
end

"""
    inspect_constructor(IteratorType, args...; kwargs...)

Implementation of [`@inspect`](@ref): builds the iterator on top of a [`TracingSolver`](@ref)
and starts an inspection.
"""
function inspect_constructor(IT::Type{<:ProgramIterator}, args...;
    max_events::Int=100_000, logging::Bool=false, kwargs...)

    _install_dispatch_bridges!() # pick up constraints defined after HerbSearch was loaded
    trace = Trace(max_events=max_events, logging=logging)
    kw = Dict{Symbol,Any}(kwargs)
    inspect_kwargs = Dict{Symbol,Any}()
    for key ∈ (:live, :prefetch, :max_programs, :output, :open_browser, :title, :buffer, :spawn)
        haskey(kw, key) && (inspect_kwargs[key] = pop!(kw, key))
    end
    max_size = Int(get(kw, :max_size, typemax(Int)))
    max_depth = Int(get(kw, :max_depth, typemax(Int)))

    if haskey(kw, :solver)
        solver = pop!(kw, :solver)
        solver = solver isa TracingSolver ? solver : TracingSolver(solver, trace)
        iter = IT(args...; solver=solver, kw...)
    else
        length(args) >= 2 || throw(ArgumentError(
            "@inspect expects `IteratorType(grammar, start_symbol, ...)` or a `solver=` keyword"))
        grammar = args[1]::AbstractGrammar
        start = args[2]
        solver = tracing_generic_solver(grammar, start; trace=trace,
            max_size=max_size, max_depth=max_depth)
        iter = IT(args[3:end]...; solver=solver, kw...)
    end

    haskey(inspect_kwargs, :title) || (inspect_kwargs[:title] = string(nameof(IT)))
    return inspect(iter; logging=logging, inspect_kwargs...)
end

"""
    @inspect BFSIterator(grammar, :Int; max_depth=4)
    @inspect BFSIterator(grammar, :Int) live=false max_programs=50

Construct a program iterator on top of a solver that records everything it does and open an
interactive visualisation of

1. every AST the iterator emits (with rule indices or grammar primitives),
2. the search queue after every emitted program, and
3. every constraint propagation the solver performed, step by step.

The search is lazy: it is suspended between requests and only runs as far as the page (or
[`advance!`](@ref)) asks it to.

Options are passed after the constructor call: `live`, `prefetch`, `max_programs`,
`max_events`, `output`, `open_browser`, `logging`, `title`, `buffer` and `spawn`. All other
keyword arguments go to the iterator.

Returns the [`Inspection`](@ref); `close(insp)` shuts the search and the server down.
"""
macro inspect(ex, opts...)
    extra = Expr[]
    for opt ∈ opts
        (opt isa Expr && opt.head === :(=)) ||
            throw(ArgumentError("@inspect options must be of the form `key=value`, got `$opt`"))
        push!(extra, Expr(:kw, opt.args[1], esc(opt.args[2])))
    end

    if ex isa Expr && ex.head === :call
        positional = Any[]
        keywords = Expr[]
        for arg ∈ ex.args[2:end]
            if arg isa Expr && arg.head === :parameters
                for p ∈ arg.args
                    if p isa Expr && p.head === :kw
                        push!(keywords, Expr(:kw, p.args[1], esc(p.args[2])))
                    else
                        push!(keywords, Expr(:kw, p, esc(p)))
                    end
                end
            elseif arg isa Expr && arg.head === :kw
                push!(keywords, Expr(:kw, arg.args[1], esc(arg.args[2])))
            else
                push!(positional, esc(arg))
            end
        end
        return Expr(:call, GlobalRef(@__MODULE__, :inspect_constructor),
            Expr(:parameters, keywords..., extra...), esc(ex.args[1]), positional...)
    end
    # `@inspect some_existing_iterator`
    return Expr(:call, GlobalRef(@__MODULE__, :inspect),
        Expr(:parameters, extra...), esc(ex))
end

function _open_in_browser(target::AbstractString)
    try
        if Sys.isapple()
            run(`open $target`)
        elseif Sys.iswindows()
            run(`cmd /c start $target`)
        else
            run(`xdg-open $target`)
        end
    catch err
        @warn "Could not open the inspector in a browser, open it manually." target exception = err
    end
    return target
end
