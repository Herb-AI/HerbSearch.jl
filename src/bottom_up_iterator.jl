"""
    mutable struct BottomUpIterator <: ProgramIterator

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
    addrs::AbstractVector{AbstractAddress}
end



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

function remaining_combinations(state::BottomUpState)::AbstractVector end
function state_tracker(state::BottomUpState) end
function new_combinations!(state::BottomUpState, new_combination::AbstractVector) end
function new_state_tracker!(state::BottomUpState, new_tracker) end

has_remaining_iterations(state::BottomUpState) = isempty(remaining_combinations(state))


"""
mutable struct GenericBUState

Generic Buttom up state tracker that is sufficient in most cases.
It contains two fields:
 - combinations: which containts a vector of program combinations (addresses) used to construct new programs
 - combine_stage_tracker: which maintains the state `combine` function manipulates
"""
mutable struct GenericBUState <: BottomUpState
    combinations::AbstractVector
    combine_stage_tracker
end

remaining_combinations(iter::BottomUpState) = iter.combinations
state_tracker(iter::BottomUpState) = iter.combine_stage_tracker
function new_combinations!(state::BottomUpState, new_combs::AbstractVector)
    state.combinations = new_combs
end
function new_state_tracker!(state::BottomUpState, new_tracker)
    state.combine_stage_tracker = new_tracker
end


function create_bank!(iter::BottomUpIterator)
end

function populate_bank!(iter::BottomUpIterator)::AbstractVector

end

function combine(iter::BottomUpIterator, state)

end

function add_to_bank(iter::BottomUpIterator, program::AbstractRuleNode, address)

end

function new_address(iter::BottomUpIterator, program_combination)

end

retrieve(iter::BottomUpIterator, address) = iter.bank[address]

"""
Conventions for the combine function:
- address is a single entry -> retrieve the program from the bank
- address of length more than 1 -> first element is the top operator, the remaining ones are the arguments
"""

"""
BottomUpState needs to keep the inner combinations that are left to be processed and the inner state to be passed to combine
"""



"""
    Base.iterate(iter::BottomUpIterator)

Describes the iteration for a given [`BottomUpIterator`](@ref) over the grammar. The iteration constructs and populates the bank stored in the iterator.
"""
function Base.iterate(iter::BottomUpIterator)
    create_bank!(iter)
    addresses = populate_bank!(iter)

    retrieve(iter, addresses[begin]), GenericBUState(addresses[begin+1:end], nothing)
end


function Base.iterate(iter::BottomUpIterator, state::BottomUpState)
    program_combination, new_state = _get_next_program(iter, state)
    program = _construct_program(iter, program_combination)

    keep = add_to_bank(iter, program, new_address(iter, program_combination))

    if keep
        return program, new_state
    else
        return Base.iterate(iter, new_state)
    end
end

function _get_next_program(iter::BottomUpIterator, state::BottomUpState)::Tuple{BottomUpIterator,BottomUpState}
    if has_remaining_iterations(state)
        return remaining_combinations(state)[begin], BottomUpState(remaining_combinations(state)[begin+1:end], next_state(state))
    else
        new_combinations, new_state = combine(iter, next_state(state))
        new_combinations[begin], BottomUpState(new_combinations[begin+1:end], new_state)
    end
end

function _construct_program(iter::BottomUpIterator, addresses)

end
