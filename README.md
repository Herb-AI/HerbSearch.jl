[![codecov](https://codecov.io/gh/Herb-AI/HerbSearch.jl/graph/badge.svg?token=VUK6MXLCU4)](https://codecov.io/gh/Herb-AI/HerbSearch.jl)
[![Build Status](https://github.com/Herb-AI/HerbSearch.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/Herb-AI/HerbSearch.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Dev-Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://Herb-AI.github.io/Herb.jl/dev)

# HerbSearch.jl

This package contains search procedure implementations for the Herb Program Synthesis framework. 

For full documentation please see the [`Herb.jl` documentation](https://herb-ai.github.io/Herb.jl/dev/).

## Getting started
For a quick tutorial on how to get started with using `HerbSearch.jl` have a look at our [introductory tutorial](https://herb-ai.github.io/Herb.jl/dev/get_started/) or [Advanced search procedures](https://herb-ai.github.io/Herb.jl/dev/tutorials/advanced_search/).

## Inspecting a search (`@inspect`)

`@inspect` wraps an iterator's solver in a recorder and opens an interactive page on it:

```julia
using HerbGrammar, HerbConstraints, HerbSearch

g = @csgrammar begin
    Int = 1
    Int = x
    Int = Int + Int
    Int = Int * Int
end
addconstraint!(g, Forbidden(RuleNode(3, [RuleNode(1), VarNode(:a)])))

insp = @inspect BFSIterator(g, :Int; max_depth=3)
```

**Nothing is enumerated up front.** The search runs on its own task and is suspended
between requests; the page pulls it forward one propagation or one program at a time, so
inspecting an unbounded search is fine. `close(insp)` shuts the search and the server down.

The page has four tabs:

- **Programs** — the ASTs the iterator emits, rendered as trees. The checkbox in the header
  switches every node between the rule index and the grammar primitive it stands for.
- **Search queue** — the search queue after every emitted program. The first entry is the
  one that gets popped next; clicking an entry shows its (partial) tree, whether it is a
  generic solver state or a uniform tree.
- **Propagation** — every constraint propagation the solver performed, in order. `◀`/`▶`
  (or the arrow keys) step forward and back; the page shows the constraint, the path it was
  posted at, the rules it removed and the resulting tree, with the affected nodes
  highlighted. The "showing: after/before" button flips between the state before and after
  the propagation.
- **Grammar** — the rules and constraints, for reference.

The header has three buttons that resume the suspended search: one propagation, one
program, or ten programs. `▶` in the propagation tab and the right arrow key do the same,
so you can walk into a fix point that has not happened yet.

Options are given after the constructor call: `live`, `prefetch`, `max_events`, `output`,
`open_browser`, `logging`, `title`, `buffer` and `spawn`. Every other keyword goes to the
iterator.

There is **no cap on how far a live inspection can be pulled** — `prefetch` only decides how
much is computed before the page opens. `max_programs` applies to `live=false` only, which
enumerates that many programs up front and writes a static, self-contained page:

```julia
@inspect BFSIterator(g, :Int; max_depth=3) live=false max_programs=200 output="search.html"
```

The one ceiling that does bite is `max_events` (default `100_000`): past that the solver
stops *recording* — the search itself is unaffected, but the trace stops growing. Raise it
if you are inspecting a long run.

### Driving it from Julia

`@inspect` returns an `Inspection`, which is the same thing the page talks to:

```julia
insp = @inspect BFSIterator(g, :Int; max_depth=3) open_browser=false prefetch=0

advance!(insp; events = 1)     # exactly one propagation, then suspend again
advance!(insp; programs = 5)   # ... until five more programs have been emitted
insp.steps                     # the programs pulled so far, with their queue state
chronological(insp)            # the solver events, in the order they started
run_to_end!(insp)              # or just enumerate everything
close(insp)
```

### Reactive front ends (Observables, Makie, Pluto)

Load `Observables` and `observe(insp)` gives you observables that are updated on every
`advance!`, which is what a Makie app or a Pluto notebook needs to render a search that is
still running:

```julia
using Observables

obs = observe(insp)            # (; steps, events, latest, finished)
on(obs.latest) do event
    isnothing(event) || println(event.name, " → ", length(event.changes), " deduction(s)")
end
advance!(insp; events = 20)
```

`Observables` is a weak dependency: `HerbSearch` itself stays dependency free, and the
`InspectObservablesExt` extension loads only if you have it.

### Logging instead of a UI

`logging=true` also emits every solver event as a `@debug` message tagged with
`_group = :herb_inspect`, so the trace can be routed with the normal logging stack (e.g.
`LoggingExtras.EarlyFilteredLogger`) instead of a page:

```julia
using LoggingExtras

logger = EarlyFilteredLogger(log -> log.group === :herb_inspect, global_logger())
with_logger(logger) do
    insp = @inspect BFSIterator(g, :Int; max_depth=3) live=false max_programs=10 logging=true
end
```

### Threads

The search always runs on its own task. `spawn=true` puts that task on another thread and
`buffer=n` lets it compute up to `n` items ahead of the consumer, so the search and the
front end really run in parallel. This is safe — the solver is only ever touched by the
search task and consumers only ever see immutable snapshots — but it makes the recording
non-deterministic in time, so it is off by default.

If you want to help developing this project, initialize the project with 
```shell
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```
