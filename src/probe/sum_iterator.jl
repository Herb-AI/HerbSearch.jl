"""
struct SumIterator

This struct is used to generate all possible combinations of `number_of_elements` numbers that sum up to `desired_sum`.
The number will be in range `1:max_value` inclusive.

!!! warning 
    This iterator mutates the state in place. Deepcopying the state for each iterartion is needed to have an overview of all the possible combinations.

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
Base.@kwdef struct SumIterator
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
        # if we are about to finish the last element
        if state.current_index == iter.number_of_elements
            # if we can put the sum_left as the last element
            # println("last element")
            sum_left = iter.desired_sum - state.current_sum
            if 1 <= sum_left <= iter.max_value
                state.current_elements[state.current_index] = sum_left
                state.current_sum = iter.desired_sum
                return state.current_elements, state
            else 
                # we can't put it there so decrease the index
                state.current_sum -= state.current_elements[state.current_index]
                state.current_elements[state.current_index] = 0
                state.current_index -= 1
                if state.current_index == 0
                    return nothing
                end
            end
        end
        sum_left = iter.desired_sum - state.current_sum
        starting = state.current_elements[state.current_index] 
        next_value = starting + 1 # next value to try
        max_value = min(starting + sum_left, iter.max_value)
        if next_value <= max_value
            state.current_sum += 1 # increase sum by 1
            state.current_elements[state.current_index] += 1
            # go do the next index
            state.current_index += 1
        else
            state.current_sum -= state.current_elements[state.current_index]
            state.current_elements[state.current_index] = 0
            state.current_index -= 1
        end
    end
    return nothing
end