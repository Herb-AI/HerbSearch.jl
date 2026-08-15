[![codecov](https://codecov.io/gh/Herb-AI/HerbSearch.jl/graph/badge.svg?token=VUK6MXLCU4)](https://codecov.io/gh/Herb-AI/HerbSearch.jl)
[![Build Status](https://github.com/Herb-AI/HerbSearch.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/Herb-AI/HerbSearch.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Dev-Docs](https://img.shields.io/badge/docs-latest-blue.svg)](https://Herb-AI.github.io/Herb.jl/dev)

# HerbSearch.jl

This package contains search procedure implementations for the Herb Program Synthesis framework. 

For full documentation please see the [`Herb.jl` documentation](https://herb-ai.github.io/Herb.jl/dev/).

## Getting started
For a quick tutorial on how to get started with using `HerbSearch.jl` have a look at our [introductory tutorial](https://herb-ai.github.io/Herb.jl/dev/get_started/) or [Advanced search procedures](https://herb-ai.github.io/Herb.jl/dev/tutorials/advanced_search/).

## Inspecting a search (`@inspect`)

`@inspect` wraps an iterator's solver in a recorder, runs the search and writes a
self-contained interactive HTML page:

```julia
using HerbGrammar, HerbConstraints, HerbSearch

g = @csgrammar begin
    Int = 1
    Int = x
    Int = Int + Int
    Int = Int * Int
end
addconstraint!(g, Forbidden(RuleNode(3, [RuleNode(1), VarNode(:a)])))

@inspect BFSIterator(g, :Int; max_depth=3) max_programs=25
```

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

Options are given after the constructor call: `max_programs`, `max_events`, `output` (where
to write the page), `open_browser` and `title`. Every other keyword goes to the iterator.
`@inspect` returns the `Inspection`, so the recording can also be inspected from Julia
(`insp.steps`, `insp.trace.events`).

If you want to help developing this project, initialize the project with 
```shell
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```
