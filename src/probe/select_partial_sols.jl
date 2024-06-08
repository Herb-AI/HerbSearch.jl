select_partial_solution(partial_sols::Vector{ProgramCache}, all_selected_psols::Set{ProgramCache}) = selectpsol_largest_subset(partial_sols, all_selected_psols)

"""
    selectpsol_largest_subset(partial_sols::Vector{ProgramCache}}, all_selected_psols::Set{ProgramCache})) 

This scheme selects a single cheapest program (first enumerated) that 
satisfies the largest subset of examples encountered so far across all partial_sols.
"""
function selectpsol_largest_subset(partial_sols::Vector{ProgramCache}, all_selected_psols::Set{ProgramCache})
    if isempty(partial_sols)
        return Vector{ProgramCache}()
    end
    push!(partial_sols, all_selected_psols...)
    largest_subset_length = 0
    cost = typemax(Int)
    best_sol = partial_sols[begin]
    for psol in partial_sols
        len = length(psol.correct_examples)
        if len > largest_subset_length || len == largest_subset_length && psol.cost < cost
            largest_subset_length = len
            best_sol = psol
            cost = psol.cost
        end
    end
    return [best_sol]
end

"""
    selectpsol_first_cheapest(partial_sols::Vector{ProgramCache}}, ::Set{ProgramCache})) 

This scheme selects a single cheapest program (first enumerated) that 
satisfies a unique subset of examples.
"""
function selectpsol_first_cheapest(partial_sols::Vector{ProgramCache}, ::Set{ProgramCache})
    # maps subset of examples to the cheapest program 
    mapping = Dict{Vector{Int},ProgramCache}()
    for sol ∈ partial_sols
        examples = sol.correct_examples
        if !haskey(mapping, examples)
            mapping[examples] = sol
        else
            # if the cost of the new program is less than the cost of the previous program with the same subset of examples replace it
            if sol.cost < mapping[examples].cost
                mapping[examples] = sol
            end
        end
    end
    # get the cheapest programs that satisfy unique subsets of examples
    return collect(values(mapping))
end

"""
    selectpsol_all_cheapest(partial_sols::Vector{ProgramCache}, ::Set{ProgramCache}) 

This scheme selects all cheapest programs that satisfies a unique subset of examples.
"""
function selectpsol_all_cheapest(partial_sols::Vector{ProgramCache}, ::Set{ProgramCache})
    # maps subset of examples to the cheapest program 
    mapping = Dict{Vector{Int},Vector{ProgramCache}}()
    for sol ∈ partial_sols
        examples = sol.correct_examples
        if !haskey(mapping, examples)
            mapping[examples] = [sol]
        else
            # if the cost of the new program is less than the cost of the first program
            progs = mapping[examples]
            if sol.cost < progs[begin].cost
                mapping[examples] = [sol]
            elseif sol.cost == progs[begin].cost
                # append to the list of cheapest programs
                push!(progs, sol)
            end
        end
    end
    # get all cheapest programs that satisfy unique subsets of examples
    return collect(Iterators.flatten(values(mapping)))
end

"""
    select_partial_solution(partial_sols::Vector{ProgramCacheTrace}, all_selected_psols::Set{ProgramCacheTrace})

Select five programs with the highest reward.
"""
function select_partial_solution(partial_sols::Vector{ProgramCacheTrace}, all_selected_psols::Set{ProgramCacheTrace})
    if isempty(partial_sols)
        return Vector{ProgramCache}()
    end
    push!(partial_sols, all_selected_psols...)
    # sort partial solutions by reward
    sort!(partial_sols, by=x -> x.reward, rev=true)
    to_select = 5
    return partial_sols[1:min(to_select, length(partial_sols))]
end
