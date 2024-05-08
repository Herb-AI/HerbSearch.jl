"""
struct SumIterator

This struct is used to generate all possible combinations of `number_of_elements` numbers that sum up to `desired_sum`.
The number will be in range `1:max_value` inclusive.

!!! warning 
    This iterator mutates the state in place. Deepcopying the state for each iteartion is needed to have an overview of all the possible combinations.

# Example 
```julia
sum_iter = HerbSearch.SumIterator(number_of_elements=4, desired_sum=5, max_value=2)
options = Vector{Vector{Int}}()
for option ∈ sum_iter
    # deep copy is needed because the iterator mutates the state in place
    push!(options, deepcopy(option))
end
```
"""
@kwdef struct SumIterator
    number_of_elements::Int
    desired_sum::Int
    max_value::Int
end
mutable struct SumIteratorState
    current_sum::Int
    current_elements::Vector{Int}
    current_index::Int
end

function Base.iterate(iter::SumIterator)
    array::Vector{Int} = fill(0, iter.number_of_elements)
    iterate(iter, SumIteratorState(0, array, 1))
end

function Base.iterate(iter::SumIterator, state::SumIteratorState)
    @assert state.current_sum == sum(state.current_elements)
    while state.current_index >= 1
        sum_left = iter.desired_sum - state.current_sum
        starting = state.current_elements[state.current_index] + 1
        # println("Starting: $starting | min(sum_left,iter.max_value) :$(min(sum_left, iter.max_value))")
        for i ∈ starting:min(starting + sum_left - 1, iter.max_value)
            state.current_sum += 1 # increase sum by 1
            state.current_elements[state.current_index] = i
            # check if we have one more element to put 
            if state.current_index == iter.number_of_elements
                # we have the correct sum
                if state.current_sum == iter.desired_sum
                    return state.current_elements, state
                end
            else
                state.current_index += 1
                return iterate(iter, state)
            end
        end
        state.current_sum -= state.current_elements[state.current_index]
        state.current_elements[state.current_index] = 0
        state.current_index -= 1
    end
    return nothing
end