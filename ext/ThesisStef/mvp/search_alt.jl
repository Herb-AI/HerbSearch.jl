

function search(;
    problem,
    grammar,
    interpreter,
    properties,
    max_iterations,
    beam_size = 10,
    max_extension_depth = 2,
    max_extension_size = 2,
    starting_symbol = :ntString,
    observation_equivalance = true,
)
    # Extract io from spec
    inputs = [io.in for io in problem.spec]
    target_outputs = [io.out for io in problem.spec]

    # Initialize set of heuristic properties as empty set
    heuristic_properties = []

    for iteration in 1:max_iterations

        # Perform beam search
        function heuristic(rulenode, child_values)
            outputs = rulenode._val

            cost = 0
            for (input, output, target_output) in zip(inputs, outputs, target_outputs)
                if isnothing(output)
                    return Inf
                end
                
                diff = Int[p(input, output) != p(input, target_output) for p in heuristic_properties]
                cost += sum(diff)
            end

            return cost
        end

        iterator = BeamIteratorAlt(grammar, starting_symbol,
            beam_size = beam_size,
            program_to_cost = heuristic,
            max_extension_depth = max_extension_depth,
            max_extension_size = max_extension_size,
            stop_expanding_beam_once_replaced = false,
            interpreter = interpreter,
            observation_equivalance = observation_equivalance,
        )

        for beam_entry in iterator
            # If solution found; well return
            if beam_entry.program._val == target_outputs
                println("\nSolution found :)")
                println(rulenode2expr(beam_entry.program, grammar))
                return beam_entry.program
            end
        end

        # Otherwise; find the property that adds the most heuristic cost to the last beam
        beam_outputs = [beam_entry.program._val for beam_entry in iterator.beam]

        best_property = nothing
        best_property_index = 0
        best_property_representation = nothing
        best_property_score = -Inf
        best_possible_score = beam_size * length(target_outputs)

        for (property_index, (property, representation)) in enumerate(properties)
            target_values = [property(input, target_output) for (input, target_output) in zip(inputs, target_outputs)]

            # if !allequal(target_values)
            #     continue
            # end

            score = 0

            for beam_entry_outputs in beam_outputs
                for (input, beam_entry_output, target_value) in zip(inputs, beam_entry_outputs, target_values)
                    score += property(input, beam_entry_output) != target_value
                end
            end

            if score > best_property_score
                best_property = property
                best_property_index = property_index
                best_property_representation = representation
                best_property_score = score
            end

            if score == best_possible_score
                break
            end
        end

        # @show beam_outputs
        println("\nIteration:\t $iteration\t\t Best score: $best_property_score\t\t Best property: $best_property_representation")
        println("Iteration:\t $iteration\t\t Best cost:  $(iterator.beam[1].cost)\t\t Best outputs:  $(beam_outputs[1])")
        # @show best_property_score
        push!(heuristic_properties, best_property)
        deleteat!(properties, best_property_index)
    end

    println("No solution found :(")

    return nothing
end