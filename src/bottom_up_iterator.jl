using HerbCore: RuleNode
import HerbGrammar.return_type

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
- [`combine`](@ref): combine the existing programs in the bank into new, more complex
  programs via [`CombineAddress`](@ref)es
- [`add_to_bank!`](@ref): possibly add a program created by the [`combine`](@ref) step to
  the bank
- [`retrieve`](@ref): retrieve the program from the bank given an [`AbstractAddress`](@ref)

A generic implementation ([`SizeBasedBottomUpIterator`](@ref)) is given with a bank that is
indexed based on the program size, meaning that each level of the bank has programs
represented by the same number of nodes. Because the implementation works using an arbitrary
grammar, the bank also must be indexed on the type of the programs to allow the
[`combine`](@ref) step to avoid constructing programs that do not adhere to the grammar.
"""
abstract type BottomUpIterator <: ProgramIterator end

"""
    struct MeasureHashedBank{M}

A bank that hashes programs on some measure of type `M` (ex: program depth,
size, etc.).
"""
struct MeasureHashedBank{M}
    bank::DefaultDict{M,DefaultDict{Symbol}}

    function MeasureHashedBank{M}() where M
        return new{M}(DefaultDict{M,DefaultDict{Symbol}}(
            () -> (DefaultDict{Symbol,Vector{AbstractRuleNode}}(
                () -> AbstractRuleNode[]))
        )
        )
    end
end

"""
    measures(mhb::MeasureHashedBank)

Retrieve the measures present in the bank `mhb`.
"""
measures(mhb::MeasureHashedBank) = keys(mhb.bank)

"""
    types(mhb::MeasureHashedBank, measure)

Retrieve the types of programs in bank `mhb` with a certain `measure`.
"""
types(mhb::MeasureHashedBank, measure) = keys(mhb.bank[measure])

"""
    programs(mhb::MeasureHashedBank, measure, type)

Retrieve the programs in bank `mhb` with a certain `measure` and `type`. 
"""
programs(mhb::MeasureHashedBank, measure, type) = mhb.bank[measure][type]
retrieve(mhb::MeasureHashedBank, address) = programs(mhb, measure(address), return_type(address))[index(address)]

@programiterator SizeBasedBottomUpIterator(
    bank=MeasureHashedBank{Int}(),
    max_combination_depth=5
) <: BottomUpIterator

function get_max_combination_depth(iter::SizeBasedBottomUpIterator)
    return iter.max_combination_depth
end

@doc """
     SizeBasedBottomUpIterator

A bottom-up iterator with a bank indexed by some measure of a program (ex:
depth, size).
""" SizeBasedBottomUpIterator

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
acc = AccessAddress(1, :Int, 1)
retrieve(iter, acc)

# output

UniformHole[Bool[0, 1, 1, 1]]
```
"""
struct AccessAddress{M,I<:Integer} <: AbstractAddress
    measure::M
    type::Symbol
    index::I
end

AccessAddress(t::Tuple) = AccessAddress(t...)

"""
    $(TYPEDSIGNATURES)

Get the measure (depth, size, etc. depending on the bank) of address `a`.
"""
function measure(a::AccessAddress)
    a.measure
end

"""
    $(TYPEDSIGNATURES)

Get the type of address `a`.
"""
function return_type(a::AccessAddress)
    a.type
end

"""
    $(TYPEDSIGNATURES)

Get the index of address `a`.
"""
function index(a::AccessAddress)
    a.index
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
        [AccessAddress(1, :Int, 1), AccessAddress(1, :Int, 1)]
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

function operator(c::CombineAddress)
    return c.op
end

function children(c::CombineAddress)
    c.addrs
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

- [`remaining_combinations`](@ref): returns an iterable of program combiantions that need to be explored

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
    combinations::AbstractVector{AbstractAddress}
    "The state that the [`combine`](@ref) function can manipulate."
    combine_stage_tracker
    "The current uniform iterator that the bottom-up search is iterating through"
    current_uniform_iterator::Union{UniformIterator,Nothing}
    "The starting node of the search"
    starting_node
end

remaining_combinations(state::GenericBUState) = state.combinations

state_tracker(state::GenericBUState) = state.combine_stage_tracker

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

Return the [`AccessAddress`](@ref)es to the newly-added programs.
"""
function populate_bank!(iter::BottomUpIterator)::AbstractVector{AccessAddress}
    grammar = get_grammar(iter.solver)

    # create the bank entry
    for t in unique(grammar.types)
        terminal_domain_for_type = grammar.isterminal .& grammar.domains[t]
        if any(terminal_domain_for_type)
            terminal_programs = UniformHole(terminal_domain_for_type, [])
            push!(programs(get_bank(iter), 1, t), terminal_programs)
        end
    end

    return [
        AccessAddress(1, t, x)
        for t in unique(grammar.types)
        for x in 1:length(programs(get_bank(iter), 1, t))
    ]
end

"""
        $(TYPEDSIGNATURES)

Get the problem bank from the `BottomUpIterator`, `iter`.
"""
get_bank(iter::BottomUpIterator) = iter.bank

"""
        $(TYPEDSIGNATURES)

Combine the largest/most costly programs currently in `iter`'s bank, using any
parameters from `state`, to create a new set of programs.

Return a vector of [`AbstractAddress`](@ref) where each address represents a program to
construct, and a (possibly updated) `state` to keep track of any information that persists
per-iteration.

If the iteration should stop, the next state should be `nothing`.
"""
function combine(iter::BottomUpIterator, state)
    addresses = Vector{CombineAddress}()
    bank = get_bank(iter)
    max_in_bank = maximum(measures(bank))
    grammar = get_grammar(iter.solver)
    terminals = grammar.isterminal
    nonterminals = .~terminals
    non_terminal_shapes = UniformHole.(partition(Hole(nonterminals), grammar), ([],))

    # if we have exceeded the maximum number of programs to generate
    if max_in_bank >= get_max_combination_depth(iter)
        return nothing, nothing
    end

    #check bound function
    function check_bound(combination)
        return 1 + maximum((measure.(combination))) > max_in_bank
    end

    function appropriately_typed(child_types)
        return combination -> child_types == return_type.(combination)
    end

    # loop over groups of rules with the same arity and child types
    for shape in non_terminal_shapes
        child_types = Tuple(grammar.childtypes[findfirst(shape.domain)])
        nchildren = length(child_types)

        # *Lazily* collect addresses, their combinations, and then filter them based on `check_bound`
        all_addresses = (
            AccessAddress(measure, typename, idx)
            for measure in measures(bank)
            for typename in types(bank, measure)
            for idx in eachindex(programs(bank, measure, typename))
        )
        all_combinations = Iterators.product(Iterators.repeated(all_addresses, nchildren)...)
        bounded_combinations = Iterators.filter(check_bound, all_combinations)
        bounded_and_typed_combinations = Iterators.filter(appropriately_typed(child_types), bounded_combinations)

        # Construct the `CombineAddress`s from the filtered combinations
        append!(addresses, map(address_combo -> CombineAddress(shape, address_combo), bounded_and_typed_combinations))
    end

    return addresses, state
end

"""
        $(TYPEDSIGNATURES)

Add the `program` (the result of combining `program_combination` to the bank of
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
    prog_cost = 1 + maximum(measure.(children(program_combination)))
    program_type = return_type(get_grammar(iter.solver), program)

    push!(programs(bank, prog_cost, program_type), program)

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
    ::BottomUpIterator,
    program_combination::CombineAddress,
    program_type::Symbol,
    idx
)::AccessAddress
    return AccessAddress(
        1 + maximum(depth.(children(program_combination))),
        program_type,
        idx
    )
end

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
    return UniformHole(operator(address).domain, [retrieve(iter, a) for a in
                                                  children(address)])
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
explore ([`remaining_combinations`](@ref)), it pops the next one
- Otherwise, it calls the the [`combine`](@ref) function again, and processes the first returned program
"""
function get_next_program(iter::BottomUpIterator, state::GenericBUState)
    if has_remaining_iterations(state) # && !isempty(first_(state))
        return popfirst!(remaining_combinations(state)), state
    elseif !isnothing(state_tracker(state))
        new_program_combinations, new_state = combine(iter, state_tracker(state))

        # Check if new_program_combinations is nothing
        if isnothing(new_program_combinations) || isempty(new_program_combinations)
            # We've reached the end of the iteration
            return nothing, nothing
        else
            new_combinations!(state, new_program_combinations)
            new_state_tracker!(state, new_state)
            return popfirst!(remaining_combinations(state)), state
        end
    else
        return nothing, nothing
    end
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
    addresses = populate_bank!(iter)

    return Base.iterate(
        iter,
        GenericBUState(
            addresses,
            init_combine_structure(iter),
            nothing,
            starting_node
        )
    )
end


"""
    Base.iterate(iter::BottomUpIterator, state::GenericBUState)::Tuple{AbstractRuleNode,GenericBUState}

The second call to iterate uses [`get_next_program`](@ref) to retrive the next program from the [`GenericBUState`](@ref) and
    - if it is `nothing`, then it returns nothing; we stop
    - if it is indexed by [``](@ref) then it has the program that is already in the bank; just returnccessAddress
    - if it is indexed by [`CombineAddress`](@ref) then it
        - it calls `construct_program` to construct the program
        - call the `add_to_bank!` function to add it to the bank
        - if it is added to the bank, then it return the program and the new state
        - if it is not added to the bank, e.g., because of observational equivalence, then it calls itself again with the new state
"""
function Base.iterate(iter::BottomUpIterator, state::GenericBUState)
    # does state contain a uniform iterator? 
    # if not exhausted: return solution
    # otherwise remove it from the state
    if !isnothing(state.current_uniform_iterator)
        next_solution = next_solution!(state.current_uniform_iterator)
        if isnothing(next_solution) || depth(next_solution) > iter.solver.max_depth
            state.current_uniform_iterator = nothing
        else
            return next_solution, state
        end
    end

    solver = iter.solver
    next_program_address, new_state = get_next_program(iter, state)

    while !isnothing(next_program_address)
        program = retrieve(iter, next_program_address)
        keep = add_to_bank!(iter, next_program_address, program)

        if keep && is_subdomain(program, state.starting_node)
            # take the program (uniform tree) convert to UniformIterator, and add to state
            # return the first concrete tree from the UniformIterator in the state (and the updated state)
            uniform_solver = UniformSolver(get_grammar(solver), program, with_statistics=solver.statistics)
            new_state.current_uniform_iterator = UniformIterator(uniform_solver, iter)
            next_solution = next_solution!(state.current_uniform_iterator)

            if isnothing(next_solution) || depth(next_solution) > iter.solver.max_depth
                new_state.current_uniform_iterator = nothing
            else
                return next_solution, new_state
            end
        end

        next_program_address, new_state = get_next_program(iter, new_state)
    end

    return nothing
end
