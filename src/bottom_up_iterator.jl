"""
    mutable struct BottomUpIterator <: ProgramIterator
using Base: AbstractCmd

Enumerates programs from a context-free grammar starting at [`Symbol`](@ref) `sym` with respect to the grammar up to a given depth and a given size.
The exploration is done by maintaining a bank of (executable) programs and ieratively exploring larger programs by combinig the ones in the bank  .
Concrete iterators may overload the following methods:
- create_bank
- populate_bank! -> puts the simplest program in the bank and returns the addresses of the programs put in there
- combine
- add_to_bank! -> rename to push!
- retrieve -> given a bank and an address, retrieve the program at a given address

"""
abstract type BottomUpIterator <: ProgramIterator end

function create_bank! end
function populate_bank! end
function combine end
function add_to_bank! end
function retrieve end

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
    addrs::NTuple{N, AccessAddress} where N
end

CombineAddress(op, addrs::AbstractVector{AccessAddress}) = CombineAddress(op, Tuple(addrs))


#TODO: PointerAbstract: iterators.product solves this?
"""
Int = 1
int = 2
Int = Int + Int

1(2): 1,2
2(6): 1+1, 1+2, 2+1, 2+2
3(14): 1+1+1, 1+1+2, 1+2+1,1+2+2, 2+1+1, 2+1+2, 2+2+1, 2+2+2
4
"""



"""
mutable struct BottomUpState

State that helps us keep track where we are while iterating through program space.
More precisely, it help to keep track and switch between the program combinations of the same compelxity and the next level of compelxity.

the following methods need to be implemented:

remaining_combinations(BottomUpState): returns an iterable of progrma combiantions that need to be explored

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
  create_bank!(iter::BottomUpIterator)::Any

Initialises a data structure representing a bank of the iterator.
It should modify the iterator itself.
TODO: add bank getters to the interface
"""
function create_bank!(iter::BottomUpIterator)
    iter.bank = DefaultDict{Int,Vector{AbstractRuleNode}}(Vector{AbstractRuleNode}())
end

"""
  populate_bank!(iter::BottomUpIterator)::AbstractVector{AccessAddress}

Fills the bank with the initial, simplest, programs.
It should return the addresses of hte programs just inserted in the bank
"""
function populate_bank!(iter::BottomUpIterator)::AbstractVector{AccessAddress}
    grammar = iter.grammar
    terminal_programs = RuleNode.(findall(grammar.isterminal))

    # create the bank entry
    iter.bank[1] = Vector{AbstractRuleNode}()

    addresses_to_return = Vector{AccessAddress}()
    # iterate over terminals and add them to the bank
    push!(iter.bank[1], terminal_programs...)

    return [AccessAddress((1, x)) for x in 1:length(iter.bank[1])]
end

"""
  combine(iter::BottomUpIterator, state)::Tuple{AbstractVector{AbstractAddress},Any}

Returns a vector of [`AbstractAddress`](@ref) each address representing a program to construct, and a `state` used to keep track of the iterations (in the style of Julia iterators).
If the iteration should stop, the next state should be `nothing`.
"""
function combine(iter::BottomUpIterator, state)
    addresses = Vector{CombineAddress}()
    max_in_bank = maximum(keys(iter.bank))
    non_terminal_rules = findall(.~iter.grammar.isterminal)

    # if we have exceeded the maximum number of programs to generate
    if max_in_bank >= state[:max]
        return nothing, nothing
    end

    #check bound function
    function check_bound(combination)
        return 1 + sum((x[1] for x in combination)) > max_in_bank
    end

    for op in non_terminal_rules
        nchildren = length(iter.grammar.childtypes[op])

        # *Lazily* collect addresses, their combinations, and then filter them based on `check_bound`
        all_addresses = ((key, idx) for key in keys(iter.bank) for idx in eachindex(iter.bank[key]))
        all_combinations = Iterators.product(Iterators.repeated(all_addresses, nchildren)...)
        filtered_combinations = Iterators.filter(check_bound, all_combinations)

        # Construct the `CombineAddress`s from the filtered combinations
        addresses = map(address_pair -> CombineAddress(op, AccessAddress.(address_pair)), filtered_combinations)
    end

    return addresses, state
end

"""
  add_to_bank!(iter::BottomUpIterator, program::AbstractRuleNode, address::AbstractAddress)::Bool

Adds the `program` to the bank of the [`BottomUpIterator`](@ref) at the given `address`.
Returns `True` if the program is added to the bank, and `False` otherwise.
For example, the function returns false if the `program` is observationally equivalent to another program already in the bank; hence, it will not be added.
"""
function add_to_bank!(iter::BottomUpIterator, program::AbstractRuleNode, address::AccessAddress)::Bool
    if program in iter.bank[address.addr[1]]
        return false
    else
        push!(iter.bank[address.addr[1]], program)
        return true
    end
end

"""
  new_address(iter::BottomUpIterator, parent_address::AbstractAddress)::AbstractAddress

Returns an [`AbstractAddress`](@ref) of the program to be added to the bank, derived from the `parent_address`
"""
function new_address(iter::BottomUpIterator, program_combination::AbstractAddress)::AbstractAddress
    return AccessAddress((1 + sum([x.addr[1] for x in program_combination.addrs]), 1))
end

"""
  retrieve(iter::BottomUpIterator, address::AccessAddress)::AbstractRuleNode

Retrieves a program from the bank indexed by the [`AccessAddress`](@ref)
"""
function retrieve(iter::BottomUpIterator, address::AccessAddress)::AbstractRuleNode
    iter.bank[address.addr[1]][address.addr[2]]
end

"""
    init_combine_structure(iter::BottomUpIterator)

Returns the initial state for the first `combine` call
"""
function init_combine_structure(iter::BottomUpIterator)
    Dict(:max => 4)
end


"""
    _construct_program(iter::BottomUpIterator, addresses::CombineAddress)::AbstractRuleNode

Constructs a program by combining programs specified by `address`.
Ideally this is impelmented only once.
"""
function _construct_program(iter::BottomUpIterator, address::CombineAddress)::AbstractRuleNode
    return RuleNode(address.op, [retrieve(iter, x) for x in address.addrs])
end


"""
    _get_next_program(iter::BottomUpIterator, state::GenericBUState)::Tuple{AbstractRuleNode,BottomUpState}

Returns the next program to explore and the updated BottomUpState:
- if there are still remaining programs from the current BU iteration to explore (`remaining_combinations(state)`), it pops the next one
- otherwise, it calls the the `combine(iter, state)` function again, and processes the first returned program
"""
function _get_next_program(iter::BottomUpIterator, state::GenericBUState)
    if has_remaining_iterations(state)
        return popfirst!(remaining_combinations(state)), state
    elseif state_tracker(state) !== nothing
        new_program_combinations, new_state = combine(iter, state_tracker(state))

        # Check if new_program_combinations is nothing
        if new_program_combinations === nothing
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

"""
    Base.iterate(iter::BottomUpIterator)

Initial call of the bottom-up iterator.
It creates the bank and populates it with initial programs.
It returns the first program and a state-tracking [`GenericBUState`](@ref) containing the remaining initial programs and the initialstate for the `combine` function
"""
function Base.iterate(iter::BottomUpIterator)
    create_bank!(iter)
    addresses = populate_bank!(iter)

    retrieve(iter, addresses[begin]), GenericBUState(addresses[begin+1:end], init_combine_structure(iter))
end

"""
    Base.iterate(iter::BottomUpIterator, state::GenericBUState)::Tuple{AbstractRuleNode,GenericBUState}

The second call to iterate uses [`_get_next_program`](@ref) to retrive the next program from the [`GenericBUState`](@ref) and
    - if it is `nothing`, then it returns nothing; we stop
    - if it is indexed by [`AccessAddress`](@ref) then it has the program that is already in the bank; just return
    - if it is indexed by [`CombineAddress`](@ref) then it
        - it calls `_construct_program` to construct the program
        - call the `add_to_bank!` function to add it to the bank
        - if it is added to the bank, then it return the program and the new state
        - if it is not added to the bank, e.g., because of observational equivalence, then it calls itself again with the new state
"""
function Base.iterate(iter::BottomUpIterator, state::GenericBUState)
    program_combination, new_state = _get_next_program(iter, state)

    if program_combination === nothing
        #program is `nothing`, so we stop
        return nothing
    elseif typeof(program_combination) == AccessAddress
        # we only need to access the program, it is already in the bank
        return retrieve(iter, program_combination), new_state
    else
        # we have to combine programs from the bank
        program = _construct_program(iter, program_combination)

        keep = add_to_bank!(iter, program, new_address(iter, program_combination))

        if keep
            return program, new_state
        else
            return Base.iterate(iter, new_state)
        end
    end
end
