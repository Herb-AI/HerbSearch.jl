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

Everything that happened between two programs being emitted by an iterator:
the program itself, the state of the search queue afterwards, and the range of
[`TraceEvent`](@ref)s that were recorded on the way there.
"""
struct SearchStep
    index::Int
    program::Union{NodeSnapshot,Nothing}
    expr::String
    queue::Vector{QueueEntry}
    first_event::Int
    last_event::Int
end

"""
    Inspection

The complete recording of an iterator run: the grammar, the emitted programs, the search
queue over time and the full constraint propagation [`Trace`](@ref).

Call [`write_html`](@ref) to turn it into an interactive page.
"""
mutable struct Inspection
    title::String
    grammar::AbstractGrammar
    trace::Trace
    steps::Vector{SearchStep}
    exhausted::Bool
    file::String
end

function Base.show(io::IO, insp::Inspection)
    print(io, "Inspection(\"", insp.title, "\", ", length(insp.steps), " programs, ",
        length(insp.trace.events), " solver events")
    isempty(insp.file) || print(io, ", ", insp.file)
    print(io, ")")
end

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

"""
    record_inspection(iter::ProgramIterator; max_programs, title) -> Inspection

Run `iter` for at most `max_programs` programs, recording the emitted programs, the search
queue after every step, and (if the iterator's solver is a [`TracingSolver`](@ref)) every
constraint propagation performed along the way.
"""
function record_inspection(iter::ProgramIterator; max_programs::Int=25,
    title::AbstractString="")
    solver = get_solver(iter)
    trace = solver isa TracingSolver ? _trace(solver) : Trace()
    grammar = get_grammar(iter)
    steps = SearchStep[]

    # events recorded while the solver was constructed belong to "step 0"
    for event ∈ trace.events
        event.step = 0
    end
    seen = length(trace.events)

    exhausted = false
    next = iterate(iter)
    while length(steps) < max_programs
        if isnothing(next)
            exhausted = true
            break
        end
        (program, state) = next
        index = length(steps) + 1
        for i ∈ (seen+1):length(trace.events)
            trace.events[i].step = index
        end
        push!(steps, SearchStep(index, take_snapshot(program), _program_expr(program, grammar),
            _snapshot_queue(_queue_of(state)), seen + 1, length(trace.events)))
        seen = length(trace.events)
        next = iterate(iter, state)
    end
    # events produced by the final (unsuccessful) iterate call
    for i ∈ (seen+1):length(trace.events)
        trace.events[i].step = length(steps) + 1
    end

    name = isempty(title) ? string(nameof(typeof(iter))) : String(title)
    return Inspection(name, grammar, trace, steps, exhausted, "")
end

"""
    inspect(iter::ProgramIterator; kwargs...) -> Inspection

Record `iter` and write an interactive HTML page for it.

# Keyword arguments
- `max_programs`: how many programs to enumerate (default `25`)
- `output`: where to write the page (default: a temporary file)
- `open_browser`: open the page in the default browser (default `true`)
- `title`: title of the page

Prefer [`@inspect`](@ref), which also traces the construction of the solver.
"""
function inspect(iter::ProgramIterator; max_programs::Int=25, output::AbstractString="",
    open_browser::Bool=true, title::AbstractString="")
    insp = record_inspection(iter; max_programs=max_programs, title=title)
    file = isempty(output) ? joinpath(tempdir(), "herb_inspect_$(getpid()).html") : String(output)
    write_html(insp, file)
    open_browser && _open_in_browser(file)
    return insp
end

"""
    inspect_constructor(IteratorType, args...; kwargs...)

Implementation of [`@inspect`](@ref): builds the iterator on top of a [`TracingSolver`](@ref),
records a run and writes the page.
"""
function inspect_constructor(IT::Type{<:ProgramIterator}, args...;
    max_programs::Int=25, max_events::Int=100_000, output::AbstractString="",
    open_browser::Bool=true, title::AbstractString="", kwargs...)

    _install_dispatch_bridges!() # pick up constraints defined after HerbSearch was loaded
    trace = Trace(max_events=max_events)
    kw = Dict{Symbol,Any}(kwargs)
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

    isempty(title) && (title = string(nameof(IT)))
    return inspect(iter; max_programs=max_programs, output=output,
        open_browser=open_browser, title=title)
end

"""
    @inspect BFSIterator(grammar, :Int; max_depth=4)
    @inspect BFSIterator(grammar, :Int) max_programs=50 open_browser=false

Construct a program iterator on top of a solver that records everything it does, run it, and
open an interactive visualisation of

1. every AST the iterator emits (with rule indices or grammar primitives), and
2. every constraint propagation the solver performed, step by step.

Options are passed after the constructor call: `max_programs`, `max_events`, `output`,
`open_browser` and `title`. All other keyword arguments go to the iterator.

Returns the [`Inspection`](@ref); the generated file is in its `file` field.
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

function _open_in_browser(file::AbstractString)
    try
        if Sys.isapple()
            run(`open $file`)
        elseif Sys.iswindows()
            run(`cmd /c start $file`)
        else
            run(`xdg-open $file`)
        end
    catch err
        @warn "Could not open the inspector in a browser, open it manually." file exception = err
    end
    return file
end
