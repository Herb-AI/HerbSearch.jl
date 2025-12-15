
function generate_shortest_paths(;
    grammar,
    start_symbol,
    max_enumerations,
    interpreter,
)
    # iterator = SizeBasedBottomUpIterator(grammar, start_symbol)
    iterator = BFSIterator(grammar, start_symbol)

    states = []
    program_to_state = Dict()
    path_to_size = Dict()

    for program ∈ Iterators.take(iterator, max_enumerations)
        state = interpreter(program)

        if isnothing(state) || state in states
            continue
        end

        push!(states, state)

        program_to_state["$program"] = state
        path_to_size[(state, state)] = 0
        size = length(program)

        for child ∈ get_children(program)
            if !haskey(program_to_state, "$child")
                continue    
            end

            child_state = program_to_state["$child"]
            
            for ((state_in, state_out), distance) in path_to_size
                if child_state == state_out
                    path_to_size[(state_in, state)] = distance + (size - length(child) - 1)
                end
            end
        end
    end

    return states, path_to_size
    # return program_to_state
end

function first_n_states(;
    grammar,
    start_symbol,
    amount_of_states,
    max_enumerations,
    interpreter,
)
    # iterator = SizeBasedBottomUpIterator(grammar, start_symbol)
    iterator = BFSIterator(grammar, start_symbol)

    states = []
    programs = []
    iterations = 0

    for program ∈ iterator
        state = interpreter(program)

        if isnothing(state) || state in states
            continue
        end

        push!(states, state)
        push!(programs, deepcopy(program))

        iterations += 1
        if length(states) >= amount_of_states || iterations >= max_enumerations
            break
        end
    end

    return states, programs
end