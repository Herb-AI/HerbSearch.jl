"""
    InspectObservablesExt

Bridges a lazy [`HerbSearch.Inspection`](@ref) to `Observables`, so that reactive front ends
(Makie, Pluto, ...) can render a search that is being pulled forward.

The inspection itself stays dependency free: this extension only wraps
[`HerbSearch.on_update!`](@ref).
"""
module InspectObservablesExt

using HerbSearch
using Observables

"""
    observe(insp::Inspection)

Return `(; steps, events, latest, finished)` `Observable`s that are updated after every
`advance!(insp, ...)`.

```julia
obs = observe(insp)
on(obs.latest) do event
    isnothing(event) || println(event.name, " → ", length(event.changes), " deduction(s)")
end
advance!(insp; events = 5)
```

`steps`/`events` always hold the full vectors pulled so far (`events` in chronological
order); `latest` holds the most recently completed event, or `nothing`.
"""
function HerbSearch.observe(insp::HerbSearch.Inspection)
    steps = Observable(copy(insp.steps))
    events = Observable(HerbSearch.chronological(insp))
    latest = Observable{Union{HerbSearch.TraceEvent,Nothing}}(
        isempty(insp.events) ? nothing : last(insp.events))
    finished = Observable(insp.finished)

    HerbSearch.on_update!(insp) do session
        steps[] = copy(session.steps)
        events[] = HerbSearch.chronological(session)
        latest[] = isempty(session.events) ? nothing : last(session.events)
        finished[] = session.finished
        return nothing
    end

    return (; steps, events, latest, finished)
end

end # module
