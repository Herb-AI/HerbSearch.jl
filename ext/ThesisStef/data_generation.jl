using HerbBenchmarks, HerbSearch, HerbConstraints, HerbCore, HerbGrammar
include("best_first_string_iterator.jl")
include("string_grammar.jl")

function generate_triplets_4(;
    amount_of_programs,
    max_depth,
    problem_id,
    example_ids,
)
    benchmark       = HerbBenchmarks.String_transformations_2020
    problem_grammar = get_all_problem_grammar_pairs(benchmark)[problem_id]
    problem         = problem_grammar.problem
    spec            = problem.spec[example_ids]
    start_states    = [example.in[:_arg_1] for example in spec]
    final_states    = [example.out for example in spec]
    iterator        = HerbSearch.BFSIterator(grammar, :Program, max_depth=max_depth)

    function interpret_program(program)
        try
            return [benchmark.interpret(program, benchmark.get_relevant_tags(grammar), example.in[:_arg_1]) for example in spec]
        catch e
            if typeof(e) == BoundsError
                return nothing
            else
                rethrow(e)
            end
        end
    end

    function get_parents(program)
        i = program.ind
        c = program.children

        if i == 1
            return [nothing]
        elseif i == 2
            return [c[1], RuleNode(1, [c[2]])]
        elseif i == 8
            return c[2:3]
        elseif i == 9
            return c[2:2]
        end
    end

    @show [s.str for s in start_states]
    @show [s.str for s in final_states]
    println("\nGenerating triplets")

    program_to_state = Dict("nothing" => start_states)
    shortest_paths = Dict((start_states, start_states) => 0)

    for (i, program) in enumerate(iterator)
        states = interpret_program(program)

        if isnothing(states)
            continue
        end

        # println()
        # @show i
        # @show program
        # @show states[1]

        program_to_state["$program"] = states

        if !haskey(shortest_paths, (states, states))
            shortest_paths[(states, states)] = 0
            # println("\nAdded path")
            # @show states[1]
            # @show states[1]
            # @show 0
        end

        for parent in get_parents(program)
            parent_states = program_to_state["$parent"]

            for ((states_in, states_out), size) in shortest_paths
                if states_out == parent_states && !haskey(shortest_paths, (states_in, states))
                    shortest_paths[(states_in, states)] = size + 1

                    # println("\nAdded path")
                    # @show states_in[1]
                    # @show states[1]
                    # @show size + 1
                end
            end
        end

        if i == amount_of_programs
            break
        end
    end

    # for states in Set(values(program_to_state))
    #     println(states[1])
    # end


    states = collect(Set(values(program_to_state)))
    triplets_anp = []
    equal_inputs = 0
    equal_outputs = 0

    for states_1 in states
        for states_2 in states
            if !haskey(shortest_paths, (states_1, states_2))
                # shortest_paths[(states_1, states_2)] = 100000
            end
        end
    end

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

    println("\nVisited $(length(Set(values(program_to_state)))) states")
    println("Created $(length(shortest_paths)) paths")
    @show equal_inputs
    @show equal_outputs

    return triplets_anp
end

data = generate_triplets_4(
    amount_of_programs=100, 
    max_depth=10, 
    problem_id=102, 
    example_ids=1:5,
)

#
# 2869, 5256

nothing