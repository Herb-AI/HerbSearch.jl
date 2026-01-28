import HerbGrammar.return_type

const MAX_SKETCH_ENQUEUE = 10
const MAX_UNIFORM_PER_SKETCH = 50
const PROGS_FROM_SKETCHES = Ref(0)
const SKETCH_HASH_REJECTED = Ref(0)


"""
    abstract type BottomUpIterator <: ProgramIterator

A type of iterator that maintains a bank of (executable) programs and iteratively explores
larger programs by combining the ones in the bank.

Like other [`ProgramIterator`](@ref)s, `BottomUpIterator`s enumerate programs from a
context-free grammar starting at `Symbol` `sym` with respect to the grammar up to a given
depth and a given size.

The central concept behind this interface is an _address_ ([`AbstractAddress`](@doc)).
Addresses are simply pointers into the bank. Since the bank is often a nested container (ex:
`Dict{Key,Dict{Key,...}}`), the addresses usually have multiple components. The first
components indexes the top-most level of the bank, the second indexes, the next level, etc.
Program combinations can be expressed as a special address ([`CombineAddress`](@ref)) that
contains one or more programs and an operator. For example: combining the programs `1 + x`
and `x * x` with the `+` operator results in the program `(1 + x) + (x * x)`.

The interface for bottom-up iteration is defined as follows.

- [`get_bank`](@ref): get the iterator's bank
- [`populate_bank!`](@ref): initialize the bank with the terminals from the grammar
  and return the resulting [`AccessAddress`](@ref)es
- [`get_measure_limit`](@ref): describes the maximum limit with respect to the measure defined.
- [`combine`](@ref): combine the existing programs in the bank into new, more complex
  programs via [`CombineAddress`](@ref)es
- [`add_to_bank!`](@ref): possibly add a program created by the [`combine`](@ref) step to
  the bank
- [`retrieve`](@ref): retrieve the program from the bank given an [`AbstractAddress`](@ref)

A generic implementation ([`SizeBasedBottomUpIterator`](@ref)) is given with a bank that is indexed based on the program size, meaning that each level of the bank has programs represented by the same number of nodes. 
Because the implementation works using an arbitrary grammar, the bank also must be indexed on the type of the programs to allow the [`combine`](@ref) step to avoid constructing programs that do not adhere to the grammar.
"""
abstract type BottomUpIterator <: ProgramIterator end

function get_measure_limit end
function calc_measure end 

abstract type AbstractBankEntry end

"""

"""
mutable struct BankEntry <: AbstractBankEntry
    program::AbstractRuleNode
    is_new::Bool
    is_sketch_new::Bool 
end

is_new(entry::BankEntry) = entry.is_new
get_program(entry::BankEntry) = entry.program


"""
    struct MeasureHashedBank{M}

A bank that hashes programs on some measure of type `M` (ex: program depth,
size, etc.).
"""
struct MeasureHashedBank{M}
    bank::DefaultDict{Symbol,DefaultDict{M,Vector{BankEntry}}}
    seen_outputs::DefaultDict{Symbol,Set{OutputSig}}
    function MeasureHashedBank{M}() where M
        inner_bank = () -> DefaultDict{M,Vector{BankEntry}}(() -> BankEntry[])
        seen = DefaultDict{Symbol,Set{OutputSig}}(() -> Set{OutputSig}())
        return new{M}(
            DefaultDict{Symbol,DefaultDict{M,Vector{BankEntry}}}(inner_bank), seen
        )
    end
end


"""
    get_types(mhb::MeasureHashedBank, measure)

Retrieve the types of programs in bank `mhb`.
"""
get_types(mhb::MeasureHashedBank) = keys(mhb.bank)

"""
    get_measures(mhb::MeasureHashedBank)

Retrieve the measures present in the bank `mhb` with a certain type.
"""
get_measures(mhb::MeasureHashedBank, type::Symbol) = keys(mhb.bank[type])


"""
    get_entries(mhb::MeasureHashedBank, measure, type)

Retrieve all bank entries in bank `mhb` with a certain `type` and `measure`. 
"""
get_entries(mhb::MeasureHashedBank, type::Symbol, measure) = mhb.bank[type][measure]

"""
    programs(mhb::MeasureHashedBank, measure, type)

Retrieve the programs in bank `mhb` with a certain `type` and `measure`. 
"""
get_programs(mhb::MeasureHashedBank, type::Symbol, measure) = (e.program for e in mhb.bank[type][measure]) |> collect

"""
    AbstractAddress

Abstract type for addresses. Addresses point to (combinations of) programs in the bank.
"""
abstract type AbstractAddress end

"""
    $(TYPEDEF)

Address pointing to a single program in a bank.

# Fields

$(FIELDS)

# Examples

Given the simple grammar `g`, the following example retrieves the lone initial program
(actually a [`UniformHole`](@ref) representing all terminals in the grammar `g`) from the
bank.

```jldoctest; setup = :(using HerbCore, HerbGrammar, HerbSearch)
g = @csgrammar begin
        Int = Int + Int
        Int = 1 | 2 | 3
end
iter = SizeBasedBottomUpIterator(g, :Int)
populate_bank!(iter)
acc = AccessAddress(:Int, 1, 1, 1, 1, false)
retrieve(iter, acc)

# output

UniformHole[Bool[0, 1, 1, 1]]
```
"""
struct AccessAddress{M,I<:Integer} <: AbstractAddress
    type::Symbol
    measure::M
    index::I
    depth::Int64
    size::Int64
    new_shape::Bool
    
end

AccessAddress(t::Tuple) = AccessAddress(t...)

is_new_shape(a::AccessAddress) = a.new_shape

"""
    $(TYPEDSIGNATURES)

Get the measure (depth, size, etc. depending on the bank) of address `a`.
"""
function get_measure(a::AccessAddress)
    a.measure
end

"""
    $(TYPEDSIGNATURES)

Get the type of address `a`.
"""
function get_return_type(a::AccessAddress)
    a.type
end

"""
    $(TYPEDSIGNATURES)

Get the index of address `a`.
"""
function get_index(a::AccessAddress)
    a.index
end

"""
    $(TYPEDSIGNATURES)


"""
function HerbCore.depth(a::AccessAddress)
    a.depth
end


"""
    $(TYPEDSIGNATURES)


"""
function Base.size(a::AccessAddress)
    a.size
end


"""
    $(TYPEDEF)

Address pointing to a combination of `N` programs from a bank to be combined using `op`.

# Fields

$(FIELDS)

# Examples

Given the grammar `g`, the following example retrieves a new program from the bank. The new
program is a [`UniformHole`](@ref) that represents all programs of the form `□ + □` where
`□` is any of the `Int` terminals in the grammar.

```jldoctest; setup = :(using HerbCore, HerbGrammar, HerbSearch)
g = @csgrammar begin
        Int = Int + Int
        Int = 1 | 2 | 3
end;
iter = SizeBasedBottomUpIterator(g, :Int);
populate_bank!(iter);
acc = CombineAddress(
        UniformHole([1, 0, 0, 0]),
        [AccessAddress(:Int, 1, 1, 1, 1, false), AccessAddress(:Int, 1, 1, 1, 1, false)]
);
retrieve(iter, acc)

# output

UniformHole[Bool[1, 0, 0, 0]]{UniformHole[Bool[0, 1, 1, 1]],UniformHole[Bool[0, 1, 1, 1]]}
```
"""
struct CombineAddress{N} <: AbstractAddress
    "The root of the AST for the combined program"
    op
    "The addresses to combine to form the new program"
    addrs::NTuple{N,AccessAddress}
end

CombineAddress(op, addrs::AbstractVector{<:AccessAddress}) = CombineAddress(op, Tuple(addrs))

function get_operator(c::CombineAddress)
    return c.op
end

function get_children(c::CombineAddress)
    c.addrs
end

abstract type WorkItem end

struct AddressItem <: WorkItem
    addr::AbstractAddress
end

struct ProgramItem <: WorkItem
    program::AbstractRuleNode
end

"""
    function Base.collect(iter::BottomUpIterator)

Return an array of all programs in the BottomUpIterator.

!!! warning
    This requires deepcopying programs from type StateHole to type RuleNode.
    If it is not needed to save all programs, iterate over the iterator manually.
"""
function Base.collect(iter::BottomUpIterator)
    @warn "Collecting all programs of a BottomUpIterator requires freeze_state"
    programs = Vector{RuleNode}()
    for program ∈ iter
        push!(programs, freeze_state(program))
    end
    return programs
end

"""
    abstract type BottomUpState

State that helps us keep track where we are while iterating through program space.
More precisely, it help to keep track and switch between the program
combinations of the same complexity and the next level of complexity.

The following methods must be implemented:

- [`remaining_combinations`](@ref): returns an iterable of program combinations that need to be explored

- [`state_tracker`](@ref): returns the state tracker for the `combine` method

- [`new_combinations!`](@ref): assign new combinations to the state

- [`new_state_tracker!`](@ref): assign new state tracker to the sate
"""
abstract type BottomUpState end

function remaining_combinations end
function state_tracker end
function new_combinations! end
function new_state_tracker! end

has_remaining_iterations(state::BottomUpState) = !isempty(remaining_combinations(state))

"""
    $(TYPEDEF)

Generic bottom-up search state

# Fields

$(FIELDS)
"""
mutable struct GenericBUState <: BottomUpState
    "A vector of program combinations to construct new programs from"
    combinations::PriorityQueue{WorkItem, Number}
    "The state that the [`combine`](@ref) function can manipulate."
    combine_stage_tracker
    "The current uniform iterator that the bottom-up search is iterating through"
    sketch_uniform_iterator::Union{UniformIterator, Nothing}
    normal_uniform_iterator::Union{UniformIterator, Nothing}
    "The starting node of the search"
    starting_node
    "The last horizon that was considered. Gives a lower bound on solutions to enumerate."
    last_horizon::Float64
    "The current horizon, enumerating only programs with measure strictly smaller than the new horizon."
    new_horizon::Float64
    "Learned structural sketches (anti-unified shapes)"
    sketches::Vector{AbstractRuleNode}

    sketch_queue::PriorityQueue{WorkItem, Float64}

    from_sketch::Bool 

    seen_outputs::Set{UInt64}

    uniform_from_sketch_count::Int 

end


remaining_combinations(state::GenericBUState) = state.combinations

state_tracker(state::GenericBUState) = state.combine_stage_tracker

#@TODO Rewrite this function and use it
function new_combinations!(state::GenericBUState, new_combs::AbstractVector)
    state.combinations = new_combs
end

function new_state_tracker!(state::GenericBUState, new_tracker)
    state.combine_stage_tracker = new_tracker
end

"""
    $(TYPEDSIGNATURES)

Fill the bank with the initial, smallest programs, likely just the terminals in
most cases.
Return the [`AbstractAddress`](@ref)es to the newly-added programs.
"""
function populate_bank!(iter::BottomUpIterator)
    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)
    limit = get_measure_limit(iter)

    # seed terminals
    for t in unique(grammar.types)
        term_mask = grammar.isterminal .& grammar.domains[t]
        if any(term_mask)
            uh = UniformHole(term_mask, [])
            push!(get_entries(bank, t, calc_measure(iter, uh)), BankEntry(uh, true, true))
        end
    end

    # collect first window
    addrs = AccessAddress[]
    for t in unique(grammar.types)
        for measure in get_measures(bank, t)
            if measure <= limit
                entries = get_entries(bank, t, measure)
                isempty(entries) && continue
                for x in 1:length(entries)
                    # initial terminals are new
                    push!(addrs, AccessAddress(t, measure, x, 1, 1, true))
                end
            end
        end
    end

    return addrs
end

"""
    $(TYPEDSIGNATURES)

Get the problem bank from the `BottomUpIterator`, `iter`.
"""
get_bank(iter::BottomUpIterator) = iter.bank




"""
$(TYPEDSIGNATURES)


Compute the **new horizon**  using the current contents of the bank.
The new_horizon is an exclusive upper bound on the window we currently try to enumerate, with the inclusive lower bound being the last_horizon. 
Both are stored in the `BottomUpState`.

Definition:
- Consider all **non-terminal shapes** (operators).
- For each shape, form the cheapest child tuple that uses
**at least one `new` child** (as marked by the bank’s `is_new` flags) and all other
children at their **cheapest existing** measures (per return type).
- The next horizon is the minimum, over those shapes, of
`1 + _calc_measure(children_tuple)`.

`_calc_measure(children_tuple)` is the sum of the children measures for `SizeBasedBottomUpIterator` and the maximum of the children measures for `DepthBasedBottomUpIterator`.


Notes:
- “Newness” is derived from the bank’s `is_new` flags on entries, **not** from horizons.
- This function does **not** mutate the bank or the state (other than reading state).
"""
function compute_new_horizon(iter::BottomUpIterator)
    bank = get_bank(iter)
    grammar = get_grammar(iter.solver)

    # Enumerate all non-terminal “shapes” (operator schemas)
    terminals_mask = grammar.isterminal
    nonterminals_mask = .~terminals_mask
    nonterminal_shapes = UniformHole.(partition(Hole(nonterminals_mask), grammar), ([],))

    # Collect, per return type:
    # - the minimum measure among ALL entries (existing minima)
    # - the minimum measure among entries currently flagged as NEW
    min_measure_by_type = Dict{Symbol, Int}()
    min_new_measure_by_type = Dict{Symbol, Int}()

    for t in get_types(bank)
        for measure in get_measures(bank, t)
            entries = get_entries(bank, t, measure) # Vector{BankEntry}
            isempty(entries) && continue

            # Update "existing" min per type
            current_min = get(min_measure_by_type, t, typemax(Int))
            min_measure_by_type[t] = min(current_min, measure)

            # Update "new" min per type if there is any new entry at this measure
            if any(e -> e.is_new, entries)
                current_new_min = get(min_new_measure_by_type, t, typemax(Int))
                min_new_measure_by_type[t] = min(current_new_min, measure)
            end
        end
    end

    # Helper: make a lightweight AccessAddress to feed into calc_measure.
    # Only measure & type matter for measure computation here.
    make_synth = (T, M, is_new=false) -> AccessAddress(T, M, 0, 1, 1, is_new)

    # Search for the cheapest result that uses ≥ 1 "new" child under any max-arity shape
    best_resulting_measure = typemax(Int)

    for shape in nonterminal_shapes
        child_types = Tuple(grammar.childtypes[findfirst(shape.domain)])

        # We need existing minima for all child types
        all(t -> haskey(min_measure_by_type, t), child_types) || continue
        # ...and at least one type that has a "new" minimum available
        any(t -> haskey(min_new_measure_by_type, t), child_types) || continue

        # Try each position as the "new" child; otherwise use existing minima
        for new_pos in eachindex(child_types)
            t_new = child_types[new_pos]
            haskey(min_new_measure_by_type, t_new) || continue

            children = ntuple(i ->
                i == new_pos ?
                make_synth(child_types[i], min_new_measure_by_type[child_types[i]], true) :
                make_synth(child_types[i], min_measure_by_type[child_types[i]], false),
                length(child_types))

            # Result measure = 1 + measure(children)
            best_resulting_measure = min(best_resulting_measure, 1 + _calc_measure(iter, children))
        end
    end

    return best_resulting_measure
end

"""
    address_stream(iter; only_new = false)

Lazy generator of AccessAddress.
"""
function address_stream(iter::BottomUpIterator; only_new::Bool)
    bank = get_bank(iter)

    return (
        begin
            entry = get_entries(bank, t, m)[i]
            prog  = entry.program
            AccessAddress(
                t, m, i,
                depth(prog),
                length(prog),
                entry.is_new
            )
        end
        for t in get_types(bank)
        for m in get_measures(bank, t)
        for i in eachindex(get_entries(bank, t, m))
        if (!only_new || get_entries(bank, t, m)[i].is_new)
    )
end

function typed_stream(iter, T; only_new=false)
    return (
        a for a in address_stream(iter; only_new=only_new)
        if get_return_type(a) == T
    )
end

function typed_stream_for_sketch(iter, T; only_new=false)
    bank = get_bank(iter)

    return (
        AccessAddress(
            T, m, i,
            depth(entry.program),
            length(entry.program),
            entry.is_new && entry.is_sketch_new
        )
        for m in get_measures(bank, T)
        for (i, entry) in enumerate(get_entries(bank, T, m))
        if !only_new || (entry.is_new && entry.is_sketch_new)
    )
end

"""
    $(TYPEDSIGNATURES)

Traverse a RuleNode (or UniformHole) AST and collect all `UniformHole`s
appearing anywhere in the tree.

This is used for sketch-based enumeration, where UniformHoles represent
unconstrained parts of a program that should be filled during bottom-up
combination (similarly to nonterminal grammar shapes).
"""
function collect_uniform_holes_from_sketch(node)::Vector{UniformHole}
    holes = UniformHole[]

    function visit(n)
        if n isa UniformHole
            push!(holes, n)
        elseif n isa RuleNode
            for c in HerbCore.get_children(n)
                visit(c)
            end
        end
    end

    visit(node)
    return holes
end


"""
    fill_sketch(sketch, hole_children)
"""
function fill_sketch(
    sketch::AbstractRuleNode,
    hole_children,
    iter::BottomUpIterator
)::AbstractRuleNode

    grammar = iter.solver.grammar
    bank    = get_bank(iter)

    hole_iter = Iterators.Stateful(hole_children)

    function rebuild(node)
        if node isa UniformHole
            # Replace hole with concrete program from bank
            return retrieve(iter, popfirst!(hole_iter))
        elseif node isa RuleNode
            new_children = map(rebuild, HerbCore.get_children(node))
            return RuleNode(get_rule(node), new_children)
        end
    end
    return rebuild(sketch)
end

function sketch_size(node::AbstractRuleNode)
    children = HerbCore.get_children(node)
    isempty(children) && return 1
    return 1 + sum(sketch_size(c) for c in children)
end

function sketch_depth(node::AbstractRuleNode)
    if node isa UniformHole
        return 0
    elseif node isa RuleNode
        return isempty(HerbCore.get_children(node)) ? 1 :
               1 + maximum(sketch_depth.(HerbCore.get_children(node)))
    end
end

function has_any_new(iter, T)
    for _ in typed_stream(iter, T; only_new=true)
        return true
    end
    return false
end

function has_any_new_sketch(iter, T)
    bank = get_bank(iter)
    for m in get_measures(bank, T)
        for entry in get_entries(bank, T, m)
            if entry.is_new && entry.is_sketch_new
                return true
            end
        end
    end
    return false
end




@inline function random_address(
    iter::BottomUpIterator,
    T::Symbol,
    max_tries::Int64
)::Union{AccessAddress,Nothing}

    bank = get_bank(iter)
    measures = get_measures(bank, T)
    isempty(measures) && return nothing

    for _ in 1:max_tries
        m = rand(measures)
        entries = get_entries(bank, T, m)
        isempty(entries) && continue

        i = rand(1:length(entries))
        entry = entries[i]

        return AccessAddress(
            T, m, i,
            depth(entry.program),
            length(entry.program),
            entry.is_new
        )
    end

    return nothing
end

struct RandomNonNewStream
    iter::BottomUpIterator
    T::Symbol
    max_tries::Int64
end

Base.iterate(s::RandomNonNewStream) =
    (random_address(s.iter, s.T, s.max_tries), nothing)

Base.iterate(s::RandomNonNewStream, _) =
    (random_address(s.iter, s.T, s.max_tries), nothing)


"""
    enqueue_sketch_expansions!(iter, state)

Enumerate concrete programs obtained by filling sketches stored in `state.sketches`
using programs from the iterator's bank.

Results are enqueued into `state.sketch_queue` as `ProgramItem`s.
This function is independent of bottom-up `combine`.
"""
function enqueue_sketch_expansions!(
    iter::BottomUpIterator,
    state::GenericBUState
)
    isempty(state.sketches) && return state



    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)

    MAX_PER_SKETCH = ceil(Int, MAX_SKETCH_ENQUEUE / length(state.sketches))

    # ---- helpers ----

    hole_type(hole::UniformHole) =
        grammar.types[findfirst(hole.domain)]

    function sketch_is_feasible(iter, sketch, child_tuple)
        base_d = sketch_depth(sketch)
        base_s = sketch_size(sketch)



        final_depth = base_d + maximum(depth.(child_tuple))
        final_size  = base_s - length(child_tuple) + sum(size.(child_tuple))


        return final_depth <= get_max_depth(iter) &&
               final_size  <= get_max_size(iter)
    end

    is_well_typed = child_types ->
        children -> child_types == get_return_type.(children)

    typed_cache = Dict{Tuple{Symbol,Bool}, Function}()
    get_stream(T, only_new) =
        get!(typed_cache, (T, only_new)) do
            () -> typed_stream_for_sketch(iter, T; only_new=only_new)
        end

    count = 0
    stop_all = false

    for sketch in state.sketches
        sketch_count = 0
        stop_sketch = false

        holes = collect_uniform_holes_from_sketch(sketch)
        isempty(holes) && continue

        if length(holes) > 5
            continue
        end

        child_types = Tuple(hole_type(h) for h in holes)
        arity       = length(child_types)
        typed_ok    = is_well_typed(child_types)

        for new_pos in 1:arity
            stop_sketch && break
            stop_all && break

            Tnew = child_types[new_pos]
            has_any_new_sketch(iter, Tnew) || continue


            streams = Vector{Any}(undef, arity)

            for i in 1:arity
                Ti = child_types[i]
                streams[i] =
                    i == new_pos ?
                    Iterators.take(get_stream(Ti, true)(), MAX_PER_SKETCH) :
                    Iterators.take(
                        RandomNonNewStream(iter, Ti, MAX_PER_SKETCH),
                        MAX_PER_SKETCH 
                    ) 
            end


    
            for child_tuple in Iterators.product(streams...)



                typed_ok(child_tuple) || continue
            
                sketch_is_feasible(iter, sketch, child_tuple) || continue
              


                first_new = findfirst(a -> a.new_shape, child_tuple)
                first_new == new_pos || continue
             
                child_measure = _calc_measure(iter, child_tuple)
                resulting_measure = sketch_size(sketch) - length(child_tuple) + child_measure
                resulting_measure > get_measure_limit(iter) && continue
             
 
                program = fill_sketch(sketch, child_tuple, iter)
                
                
                enqueue!(
                    state.sketch_queue,
                    ProgramItem(program),
                    resulting_measure
                )

                sketch_count += 1
                count += 1

                if sketch_count >= MAX_PER_SKETCH
                    stop_sketch = true
                    break
                end

                if count >= MAX_SKETCH_ENQUEUE
                    stop_all = true
                    break
                end
            end
        end

        stop_all && break
    end

    count > 0 && println("ADDED $(count) NEW programs from sketches")

    empty!(state.sketches)
    flush(stdout)

    return state
end




"""
    $(TYPEDSIGNATURES)

Combine the programs currently in `iter`'s bank to create a new set of programs.
Constructs all tuples of combinations of programs joined by an operator. 
To ensure that we only consider new programs, the tuple of existing programs has to contain at least one **new** program.
New programs are represented by `CombineAddress`es, i.e., operators over a tuple of existing programs, represented with `AccessAddress`.

Combine also calculates the new enumeration window, i.e. sets last_horizon to new_horizon and calculates new_horizon via `compute_new_horizon`.
Enqueues ALL found combinations into `state.combinations` that are bigger than last_horizon, but will NOT prune solutions that exceed the current window, i.e., new_horizon.
"""
function combine(iter::BottomUpIterator, state::GenericBUState)
    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)

    # All “shapes”, i.e., rule schemas we can combine children with
    terminals_mask     = grammar.isterminal
    nonterminals_mask  = .~terminals_mask
    nonterminal_shapes = UniformHole.(partition(Hole(nonterminals_mask), grammar), ([],))

    old_last = state.last_horizon
    old_new  = state.new_horizon

    candidate = compute_new_horizon(iter)

    if isfinite(candidate)
        candidate = min(candidate, get_measure_limit(iter))

        if candidate > old_new
            state.last_horizon = old_new
            state.new_horizon  = candidate
        end
    end

    # If we exceeded global measure limit, stop early
    if state.last_horizon > get_measure_limit(iter)
        return nothing, nothing
    end

    typed_cache = Dict{Tuple{Symbol,Bool}, Function}()

    get_stream(T, only_new) =
        get!(typed_cache, (T, only_new)) do
            () -> typed_stream(iter, T; only_new=only_new)
        end

    is_well_typed = child_types -> (children -> child_types == get_return_type.(children))

    # Enqueue candidates into the PQ window [last_horizon, new_horizon)
    # Checking solver limits
    is_feasible = function(children::Tuple{Vararg{AccessAddress}})
        maximum(depth.(children)) < get_max_depth(iter) &&
        sum(size.(children)) < get_max_size(iter)
    end
 

    # Iterate over possible shapes
    for shape in nonterminal_shapes
        child_types  = Tuple(grammar.childtypes[findfirst(shape.domain)])
        arity        = length(child_types)
        typed_filter = is_well_typed(child_types)


        for new_pos in 1:arity
            Tnew = child_types[new_pos]

            # If no new programs of this type exist → skip
            has_new = has_any_new(iter, Tnew)
            has_new || continue

            streams = Vector{Any}(undef, arity)

            for i in 1:arity
                Ti = child_types[i]
                streams[i] =
                    (i == new_pos) ?
                    get_stream(Ti, true)() :
                    get_stream(Ti, false)()
            end

            candidate_combinations = Iterators.product(streams...)
            candidate_combinations = Iterators.filter(is_feasible, candidate_combinations)

            for child_tuple in candidate_combinations
                
                # ≥1 new child is GUARANTEED by construction
                first_new = findfirst(a -> a.new_shape, child_tuple)
                first_new == new_pos || continue

                # cheap pruning
                resulting_measure = 1 + _calc_measure(iter, child_tuple)
                resulting_measure > get_measure_limit(iter) && continue
            
                enqueue!(
                    state.combinations,
                    AddressItem(CombineAddress(shape, child_tuple)),
                    resulting_measure
                )
            end
        end
    end


    # @TODO consume only enumerated shapes, not iterate over the entire bank
    for t in get_types(bank)
        for measure in get_measures(bank, t)
            for entry in get_entries(bank, t, measure)
                entry.is_new = false
            end
        end
    end



    return state.combinations, state
end



"""
        $(TYPEDSIGNATURES)

Add the `program` (the result of combining `program_combination`) to the bank of
the `iter`.

Return `true` if the `program` is added to the bank, and `false` otherwise.

For example, to implement an iterator with observational equivalence, the
function might return false if the `program` is observationally equivalent to
another program already in the bank.
"""
function add_to_bank!(
    iter::BottomUpIterator,
    program_combination::CombineAddress,
    program::AbstractRuleNode
)
    bank = get_bank(iter)
    prog_measure = calc_measure(iter, program_combination)

    # Omit programs that exceed the measure limit
    # Do not add programs to the bank that are AT the shape limit, as the combination will exceed the limit.
    if prog_measure > get_measure_limit(iter) ||
       depth(program) >= get_max_depth(iter) ||
       length(program) >= get_max_size(iter)
        return false
    end

    program_type = return_type(get_grammar(iter.solver), program)
    push!(get_entries(bank, program_type, prog_measure), BankEntry(program, true, true))
    return true
end

"""
    add_to_bank!(iter, shape, measure) -> Bool

Add a **uniform shape** (`UniformHole` / `AbstractRuleNode`) to the bank of `iter`
at the given `measure`.

This method is used for sketch-generated shapes, where the program is already
abstracted and no `CombineAddress` exists.

Returns `true` if the shape was added, `false` otherwise.
"""
function add_to_bank!(
    iter::BottomUpIterator,
    shape::AbstractRuleNode
)::Bool
    bank = get_bank(iter)

    measure = calc_measure(iter, shape)

    # Global limits
    if measure > get_measure_limit(iter) ||
       depth(shape) >= get_max_depth(iter) ||
       length(shape) >= get_max_size(iter)
        return false
    end

    grammar = get_grammar(iter.solver)
    shape_type = return_type(grammar, shape)

    push!(
        get_entries(bank, shape_type, measure),
        BankEntry(shape, true, true)
    )

    return true
end



"""
        $(TYPEDSIGNATURES)

Always return `true`. Adding an [`AccessAddress`](@ref) to the bank only happens in the
first iteration with terminals.
"""
function add_to_bank!(::BottomUpIterator, ::AccessAddress, ::AbstractRuleNode)
    return true
end

"""
        $(TYPEDSIGNATURES)

Create an [`AccessAddress`](@ref) derived from the `program_combination`
[`CombineAddress`](@ref) and `program_type`.
"""
function new_address(
    iter::BottomUpIterator,
    program_combination::CombineAddress,
    program_type::Symbol,
    idx
)::AccessAddress
    return AccessAddress(
        program_type,
        calc_measure(iter, program_combination),
        idx,
        1,
        1, #@TODO placeholders for now. Should be set properly for checking feasibility
        false
    )
end

retrieve(mhb::MeasureHashedBank, address::AccessAddress) = get_programs(mhb, get_return_type(address), get_measure(address))[get_index(address)]

"""
    $(TYPEDSIGNATURES)

Retrieve a program located at `address` from the `iter`'s bank.
"""
function retrieve(iter::BottomUpIterator, address::AccessAddress)::AbstractRuleNode
    retrieve(get_bank(iter), address)
end

"""
    $(TYPEDSIGNATURES)

Construct a program using the [`CombineAddress`](@ref) `address` and the `iter`'s bank.
"""
function retrieve(iter::BottomUpIterator, address::CombineAddress)::UniformHole
    return UniformHole(get_operator(address).domain, [retrieve(iter, a) for a in
                                                  get_children(address)])
end

"""
    $(TYPEDSIGNATURES)

Return the initial state for the first `combine` call
"""
function init_combine_structure(::BottomUpIterator)
    return Dict()
end

"""
    $(TYPEDSIGNATURES)

Return the next program to explore and the updated [`BottomUpState`](@ref).

- If there are still remaining programs from the current bottom-up iteration to
  explore ([`state.combinations`](@ref)), it pops the next one if in the current horizon window.
    - If `last_horizon == new_horizon`, exhaust the PQ at that value before advancing.
- Otherwise, it calls the [`combine`](@ref) function again, and processes the first returned program.
"""
function get_next_program(iter::BottomUpIterator, state::GenericBUState)

    if !isempty(state.sketch_queue)
        return dequeue!(state.sketch_queue), state
    end
    # Dequeue all elements from the current horizon window if last and new horizon are equal
    # OR dequeue if within horizon bounds.
    if !isempty(state.combinations)
        top = peek(state.combinations).second
       if state.last_horizon == top == state.new_horizon ||
           state.last_horizon <= top < state.new_horizon
            return dequeue!(state.combinations), state
        end
    end 

    # Everything is exhausted and compute_new_horizon will not update the window as it is already maxxed.
    if state.last_horizon == get_measure_limit(iter) || 
        state.new_horizon == typemax(typeof(get_measure_limit(iter))) ||
        state.new_horizon == Inf 
        return nothing, nothing
    end

    # If there are no elements in the queue within the current horizon window
    # Construct new solutions using combine once. If there are still no feasible solutions present, then exhaust the rest of the PQ by setting the horizon to get_measure_limit.
    if !isnothing(state_tracker(state)) 
        old_window = (state.last_horizon, state.new_horizon)
        new_program_combinations, state = combine(iter, state)

        if isnothing(new_program_combinations) 
            return nothing, nothing
        end

        window_changed = old_window != (state.last_horizon, state.new_horizon)
        # Recurse and call combine again to find concrete programs
        if window_changed
            return get_next_program(iter, state) 
        elseif !isempty(new_program_combinations)
            # If the window didn't change, exhaust the next element from the queue
            top = peek(state.combinations).second
            if state.last_horizon == top == state.new_horizon ||
               state.last_horizon <= top < state.new_horizon
                return dequeue!(state.combinations), state
            elseif state.new_horizon != get_measure_limit(iter) 
                # set measure limit to max. Thus return all solutions in state.combinations.
                state.new_horizon = get_measure_limit(iter)
                return dequeue!(state.combinations), state
            end
        else 
            return nothing, nothing
        end
    end

    return nothing, nothing
end


function derivation_heuristic(::BottomUpIterator, indices::Vector{<:Integer})
    return sort(indices)
end

"""
        $(TYPEDSIGNATURES)

Initial call of the bottom-up iterator.

Populate the bank with initial programs.

Return the first program and a state-tracking [`GenericBUState`](@ref) containing the
remaining initial programs and the initialstate for the `combine` function
"""
function Base.iterate(iter::BottomUpIterator)
    solver = iter.solver
    starting_node = deepcopy(get_tree(solver))

    # Populate bank with terminals and get their AccessAddresses
    addrs = populate_bank!(iter)

    # Priority queue keyed by address, prioritized by its measure
    pq = PriorityQueue{WorkItem, Number}(DataStructures.FasterForward())
    for acc in addrs
        enqueue!(pq, AddressItem(acc), get_measure(acc))
    end

    return Base.iterate(
        iter,
        GenericBUState(
            pq,
            init_combine_structure(iter),
            nothing,
            nothing,
            starting_node,
            -Inf, # last_horizon
            0, # new_horizon
            AbstractRuleNode[],
            PriorityQueue{WorkItem,Float64}(DataStructures.FasterForward()),
            false,
            Set{UInt64}(),
            0
        )
    )
end

function program_to_uniform_shape(node::AbstractRuleNode, grammar)

    if node isa UniformHole
        return node
    elseif node isa RuleNode
        rule = get_rule(node)

        mask = falses(length(grammar.isterminal))
        mask[rule] = true

        children = map(
            c -> program_to_uniform_shape(c, grammar),
            HerbCore.get_children(node)
        )
        return UniformHole(mask, children)
    else
        error("Unsupported node type: $(typeof(node))")
    end
end


"""
    $(TYPEDSIGNATURES)

The second call to iterate uses [`get_next_program`](@ref) to retrive the next program from the [`GenericBUState`](@ref) and
    - if it is `nothing`, then it returns nothing; we stop
    - if it is indexed by [``](@ref) then it has the program that is already in the bank; just return AccessAddress
    - if it is indexed by [`CombineAddress`](@ref) then it
        - it calls `construct_program` to construct the program
        - call the `add_to_bank!` function to add it to the bank
        - if it is added to the bank, then it return the program and the new state
        - if it is not added to the bank, e.g., because of observational equivalence, then it calls itself again with the new state
"""
function Base.iterate(iter::BottomUpIterator, state::GenericBUState)

    grammar = iter.solver.grammar

    # =========================================================
    # 1. START ONE SKETCH BURST (IF GATE OPEN)
    # =========================================================
    if isnothing(state.sketch_uniform_iterator) &&
       !isempty(state.sketch_queue)

        item = dequeue!(state.sketch_queue)
        @assert item isa ProgramItem
        program = item.program

        if is_subdomain(program, state.starting_node)
            state.sketch_uniform_iterator =
                UniformIterator(
                    UniformSolver(grammar, program;
                        with_statistics=iter.solver.statistics),
                    iter
                )
            state.uniform_from_sketch_count = 0
        else
            return Base.iterate(iter, state)
        end
    end

    # =========================================================
    # 2. SKETCH UNIFORM ENUMERATION
    # =========================================================
    if !isnothing(state.sketch_uniform_iterator)
        sol = next_solution!(state.sketch_uniform_iterator)

        if isnothing(sol)
            state.sketch_uniform_iterator = nothing
        else
            frozen = freeze_state(sol)
            h = hash(frozen)

            if h ∈ state.seen_outputs
                SKETCH_HASH_REJECTED[] += 1
                return Base.iterate(iter, state)
            end

            push!(state.seen_outputs, h)
            PROGS_FROM_SKETCHES[] += 1
            state.uniform_from_sketch_count += 1

            # println("EXPLORE SKETCH : ",
            #     rulenode2expr(frozen, grammar))

            if state.uniform_from_sketch_count >= MAX_UNIFORM_PER_SKETCH
                state.sketch_uniform_iterator = nothing

            end

            return frozen, state
        end
    end

    # =========================================================
    # 3. NORMAL UNIFORM ENUMERATION
    # =========================================================
    if !isnothing(state.normal_uniform_iterator)
        sol = next_solution!(state.normal_uniform_iterator)

        if isnothing(sol)
            state.normal_uniform_iterator = nothing
        else
            frozen = freeze_state(sol)
            h = hash(frozen)

            if h ∈ state.seen_outputs
                return Base.iterate(iter, state)
            end

            push!(state.seen_outputs, h)
            return frozen, state
        end
    end

    # =========================================================
    # 4. FETCH NEXT PROGRAM (BOTTOM-UP)
    # =========================================================
    item, state = get_next_program(iter, state)

    while !isnothing(item)

        # ------------------ SKETCH PROGRAM -------------------
        if item isa ProgramItem
            program = item.program

            if is_subdomain(program, state.starting_node)
                state.sketch_uniform_iterator = UniformIterator(
                    UniformSolver(grammar, program;
                        with_statistics=iter.solver.statistics),
                    iter
                )

                sol = next_solution!(state.sketch_uniform_iterator)
                if isnothing(sol)
                    # no solutions
                else
                    frozen = freeze_state(sol)
                    h = hash(frozen)

                    if h ∈ state.seen_outputs
                        SKETCH_HASH_REJECTED[] += 1
                        return Base.iterate(iter, state)
                    end

                    push!(state.seen_outputs, h)
                    PROGS_FROM_SKETCHES[] += 1


                    state.uniform_from_sketch_count = 1

                    return frozen, state
                end
            end

        # ------------------ NORMAL PROGRAM -------------------
        elseif item isa AddressItem
            addr = item.addr
            program = retrieve(iter, addr)
            add_to_bank!(iter, addr, program)

            if is_subdomain(program, state.starting_node)
                state.normal_uniform_iterator = UniformIterator(
                    UniformSolver(grammar, program;
                        with_statistics=iter.solver.statistics),
                    iter
                )

                sol = next_solution!(state.normal_uniform_iterator)

                if isnothing(sol)
                    state.normal_uniform_iterator = nothing
                else
                    frozen = freeze_state(sol)
                    h = hash(frozen)

                    if h ∈ state.seen_outputs
                        return Base.iterate(iter, state)
                    end

                    push!(state.seen_outputs, h)
                    return frozen, state
                end
            end
        end

        item, state = get_next_program(iter, state)
    end

    return nothing
end



"""
    print_sketch_stats(; reset=false)

Print how many programs were generated via sketch expansion.
Optionally reset the counter.
"""
function print_sketch_stats()
    println("Programs generated from sketches: ", PROGS_FROM_SKETCHES[])
    return  PROGS_FROM_SKETCHES[]
end

function print_hash_rejection_stats()
    println("Hash-rejected programs (from sketches): ", SKETCH_HASH_REJECTED[])
    return  SKETCH_HASH_REJECTED[]
end

function reset_sketch_counters!()
    PROGS_FROM_SKETCHES[] = 0
    SKETCH_HASH_REJECTED[] = 0
end
