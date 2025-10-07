using HerbBenchmarks, HerbSearch, HerbConstraints, HerbCore, HerbGrammar
include("best_first_string_iterator.jl")

function generate_triplets_2(;
    amount_of_programs,
    max_size,
    problem_id,
    example_ids,
)
    function heuristic(_, program, _)
        l = length(program)
        return l < max_size ? l : Inf
    end

    iter = BestFirstStringIterator(heuristic, max_size, false, problem_id, example_ids)

    @show [s.str for s in iter.start_states]
    @show [s.str for s in iter.final_states]
    println("\nGenerating triplets")

    shortest_paths = Dict((iter.start_states, iter.start_states) => 0)


    for (i, entry) in enumerate(iter)
        # println()
        # @show i
        # @show entry.program
        # @show entry.states[1]
        # @show entry.parent.states[1]

        # if not exists
        if !haskey(shortest_paths, (entry.states, entry.states))
            shortest_paths[(entry.states, entry.states)] = 0
        end

        for ((states_in, states_out), size) in shortest_paths
            if states_out == entry.parent.states && !haskey(shortest_paths, (states_in, entry.states))
                shortest_paths[(states_in, entry.states)] = size + 1
            end
        end

        if i == amount_of_programs
            break
        end
    end

    triplets_anp = []
    equal_inputs = 0
    equal_outputs = 0

    for ((state_in_1, state_out_1), size_1) in shortest_paths
        for ((state_in_2, state_out_2), size_2) in shortest_paths
            if size_1 < size_2
                # Case 1: equal inputs
                if state_in_1 == state_in_2
                    push!(triplets_anp, (state_in_1, state_out_1, state_out_2))
                    equal_inputs += 1
                end

                # Case 2: equal outputs
                if state_out_1 == state_out_2
                    push!(triplets_anp, (state_out_1, state_in_1, state_in_2))
                    equal_outputs += 1
                end
            end
        end
    end

    @show equal_inputs
    @show equal_outputs
    @show length(triplets_anp)

    return triplets_anp
end

data = generate_triplets(
    amount_of_programs=300, 
    max_size=10, 
    problem_id=102, 
    example_ids=1:5
)

nothing