"""
   abstract type BottomUpIterator <: ProgramIterator

Enumerates programs from a context-free grammar starting at `Symbol` `sym` with respect to the grammar up to a given depth and a given size.
The exploration is done by maintaining a bank of (executable) programs and ieratively exploring larger programs by combining the ones in the bank.
Concrete iterators may overload the following methods:
- [`get_bank`](@ref): get the iterator's bank
- [`populate_bank!`](@ref): put the simplest program(s) in the bank and return the [`AccessAddress`](@ref)es of the new programs
- [`combine`](@ref): combine the existing programs in the bank into new, more complex programs via [`CombineAddress`](@ref)es
- [`add_to_bank!`](@ref): possibly add a program created by the [`combine`](@ref) step to the bank
- [`retrieve`](@ref): retrieve the program from the bank given an [`AbstractAddress`](@ref)
"""
abstract type BottomUpIterator <: ProgramIterator end

@programiterator SizeBasedBottomUpIterator(bank=DefaultDict{Int,DefaultDict}(() -> (DefaultDict{Symbol,AbstractVector{AbstractRuleNode}}(() -> AbstractRuleNode[]))),
        max_combination_depth=5
) <: BottomUpIterator

function get_max_combination_depth(iter::SizeBasedBottomUpIterator)
        return iter.max_combination_depth
end

@doc """
        SizeBasedBottomUpIterator

A basic bottom-up iterator with a bank based on program size.
"""
SizeBasedBottomUpIterator

"""
A simple type for different addresses to allow multiple dispatch
"""
abstract type AbstractAddress end

"""
Indicates that a single program needs to be retrieved from the bank
"""
struct AccessAddress <: AbstractAddress
        addr
end

"""
indicates that several programs need to be retrieved and combined
"""
struct CombineAddress <: AbstractAddress
        op
        addrs::NTuple{N,AccessAddress} where N
end

CombineAddress(op, addrs::AbstractVector{AccessAddress}) = CombineAddress(op, Tuple(addrs))

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
        mutable struct BottomUpState

State that helps us keep track where we are while iterating through program space.
More precisely, it help to keep track and switch between the program combinations of the same compelxity and the next level of compelxity.

the following methods need to be implemented:

remaining_combinations(BottomUpState): returns an iterable of program combiantions that need to be explored

state_tracker(state:BottomUpState): returns the state tracker for the `combine` method

new_combinations!(state::BottomUpState, new_combinations): assign new combinations to the state

new_state_tracker!(state::BottomUpState, new_state): assign new state tracker to the sate
"""
abstract type BottomUpState end

function remaining_combinations end
function state_tracker end
function new_combinations! end
function new_state_tracker! end

has_remaining_iterations(state::BottomUpState) = !isempty(remaining_combinations(state))

"""
mutable struct GenericBUState

Generic Buttom up state tracker that is sufficient in most cases.
It contains two fields:
 - combinations: which containts a vector of program combinations (addresses) used to construct new programs
 - combine_stage_tracker: which maintains the state `combine` function manipulates
"""
mutable struct GenericBUState <: BottomUpState
        combinations::AbstractVector{AbstractAddress}
        combine_stage_tracker
        current_uniform_iterator::Union{UniformIterator,Nothing}
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
The following functions define the interface for bottom up iterators
"""

"""
        create_bank!(iter::BottomUpIterator)

Initialises a data structure representing a bank of the iterator.
It should modify the iterator itself.
TODO: add bank getters to the interface
"""
# function create_bank!(iter::BottomUpIterator)
# iter.bank = DefaultDict{Int,DefaultDict}(() -> (DefaultDict{Symbol,AbstractVector{AbstractRuleNode}}(() -> AbstractRuleNode[])))
# end

"""
        populate_bank!(iter::BottomUpIterator)::AbstractVector{AccessAddress}

Fills the bank with the initial, simplest, programs.
It should return the addresses of the programs just inserted in the bank
"""
function populate_bank!(iter::BottomUpIterator)::AbstractVector{AccessAddress}
        grammar = get_grammar(iter.solver)

        # create the bank entry
        for t in unique(grammar.types)
                terminal_domain_for_type = grammar.isterminal .& grammar.domains[t]
                if any(terminal_domain_for_type)
                        terminal_programs = UniformHole(terminal_domain_for_type, [])
                        push!(get_bank(iter)[1][t], terminal_programs)
                end
        end

        return [AccessAddress((1, t, x)) for t in unique(grammar.types) for x in 1:length(get_bank(iter)[1][t])]
end

"""
        get_bank(iter::BottomUpIterator)

Get the problem bank from the `BottomUpIterator`, `iter`.
"""
get_bank(iter::BottomUpIterator) = iter.bank

"""
        combine(iter::BottomUpIterator, state)::Tuple{AbstractVector{AbstractAddress},Any}

Returns a vector of [`AbstractAddress`](@ref) each address representing a program to construct, and a `state` used to keep track of the iterations (in the style of Julia iterators).
If the iteration should stop, the next state should be `nothing`.
"""
function combine(iter::BottomUpIterator, state)
        addresses = Vector{CombineAddress}()
        max_in_bank = maximum(keys(get_bank(iter)))
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
                return 1 + maximum((x[1] for x in combination)) > max_in_bank
        end

        function appropriately_typed(child_types)
                return combination -> child_types == [x[2] for x in combination]
        end

        # loop over groups of rules with the same arity and child types
        for shape in non_terminal_shapes
                child_types = grammar.childtypes[findfirst(shape.domain)]
                nchildren = length(child_types)

                # *Lazily* collect addresses, their combinations, and then filter them based on `check_bound`
                all_addresses = ((key, typename, idx) for key in keys(get_bank(iter)) for typename in keys(get_bank(iter)[key]) for idx in eachindex(get_bank(iter)[key][typename]))
                all_combinations = Iterators.product(Iterators.repeated(all_addresses, nchildren)...)
                bounded_combinations = Iterators.filter(check_bound, all_combinations)
                bounded_and_typed_combinations = Iterators.filter(appropriately_typed(child_types), bounded_combinations)

                # Construct the `CombineAddress`s from the filtered combinations
                append!(addresses, map(address_pair -> CombineAddress(shape, AccessAddress.(address_pair)), bounded_and_typed_combinations))
        end

        return addresses, state
end

"""
  add_to_bank!(iter::BottomUpIterator, program::AbstractRuleNode, address::AbstractAddress)::Bool

Adds the `program` to the bank of the [`BottomUpIterator`](@ref) at the given `address`.
Returns `True` if the program is added to the bank, and `False` otherwise.
For example, the function returns false if the `program` is observationally equivalent to another program already in the bank; hence, it will not be added.
"""
function add_to_bank!(iter::BottomUpIterator, program_combination::CombineAddress, program::AbstractRuleNode)
        program_type = get_type(get_grammar(iter.solver), program)

        bank = get_bank(iter)
        prog_cost = 1 + maximum([x.addr[1] for x in program_combination.addrs])
        n_in_bank = length(bank[prog_cost][program_type])
        address = new_address(iter, program_combination, program_type, n_in_bank + 1)

        push!(get_bank(iter)[address.addr[1]][address.addr[2]], program)

        return true
end

"""
        add_to_bank!(::BottomUpIterator, ::AccessAddress)

Always return `false` as [`AccessAddress`](@ref)es are already in the bank.
"""
function add_to_bank!(::BottomUpIterator, ::AccessAddress, ::AbstractRuleNode)
        return true
end

"""
        new_address(::BottomUpIterator, program_combination::CombineAddress, program_type::Symbol, idx)

Create an [`AccessAddress`](@ref) derived from the `program_combination` [`CombineAddress`](@ref) and `program_type`.
"""
function new_address(::BottomUpIterator, program_combination::CombineAddress, program_type::Symbol, idx)::AccessAddress
        return AccessAddress((1 + maximum([x.addr[1] for x in program_combination.addrs]), program_type, idx))
end

"""
        $(TYPEDSIGNATURES)

Retrieve a program located at `address` from the `iter`'s bank.
"""
function retrieve(iter::BottomUpIterator, address::AbstractAddress)::AbstractRuleNode
        bank = get_bank(iter)
        return retrieve(bank, address)
end

"""
        $(TYPEDSIGNATURES)

Retrieve a program located at `address` from the `bank`.
"""
function retrieve(bank, address::AccessAddress)::AbstractRuleNode
        bank[address.addr[1]][address.addr[2]][address.addr[3]]
end

"""
        $(TYPEDSIGNATURES)

Construct a program using the [`CombineAddress`](@ref) `address` and the `bank`.
"""
function retrieve(bank, address::CombineAddress)::UniformHole
        return UniformHole(address.op.domain, [retrieve(bank, a) for a in address.addrs])
end

"""
    init_combine_structure(iter::BottomUpIterator)

Returns the initial state for the first `combine` call
"""
function init_combine_structure(::BottomUpIterator)
        return Dict()
end

"""
    get_next_program(iter::BottomUpIterator, state::GenericBUState)::Tuple{AbstractRuleNode,BottomUpState}

Returns the next program to explore and the updated BottomUpState:
- if there are still remaining programs from the current BU iteration to explore (`remaining_combinations(state)`), it pops the next one
- otherwise, it calls the the `combine(iter, state)` function again, and processes the first returned program
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
    Base.iterate(iter::BottomUpIterator)

Initial call of the bottom-up iterator.
It populates the bank with initial programs.
It returns the first program and a state-tracking [`GenericBUState`](@ref) containing the remaining initial programs and the initialstate for the `combine` function
"""
function Base.iterate(iter::BottomUpIterator)
        solver = iter.solver
        starting_node = deepcopy(get_tree(solver))
        addresses = populate_bank!(iter)

        return Base.iterate(iter, GenericBUState(addresses, init_combine_structure(iter), nothing, starting_node))
end

get_type(grammar, rn::RuleNode) = grammar.types[get_rule(rn)]
get_type(grammar, uh::UniformHole) = grammar.types[findfirst(uh.domain)]

"""
    Base.iterate(iter::BottomUpIterator, state::GenericBUState)::Tuple{AbstractRuleNode,GenericBUState}

The second call to iterate uses [`get_next_program`](@ref) to retrive the next program from the [`GenericBUState`](@ref) and
    - if it is `nothing`, then it returns nothing; we stop
    - if it is indexed by [`AccessAddress`](@ref) then it has the program that is already in the bank; just return
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
