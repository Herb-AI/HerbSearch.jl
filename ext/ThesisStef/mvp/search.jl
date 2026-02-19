

function search(;
    problem,
    grammar,
    interpreter,
    properties,
    max_iterations,
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

        iterator = BeamIterator(grammar, :ntString,
            beam_size = 10,
            program_to_cost = heuristic,
            max_extension_depth = 2,
            max_extension_size = 2,
            clear_beam_before_expansion = false,
            stop_expanding_beam_once_replaced = true,
            interpreter = interpreter,
            observation_equivalance = false,
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

        for (property_index, (property, representation)) in enumerate(properties)
            score = 0

            for beam_entry_outputs in beam_outputs
                for (input, beam_entry_output, target_output) in zip(inputs, beam_entry_outputs, target_outputs)
                    score += property(input, beam_entry_output) != property(input, target_output)
                end
            end

            if score > best_property_score
                best_property = property
                best_property_index = property_index
                best_property_representation = representation
                best_property_score = score
            end
        end

        # @show beam_outputs
        println("Iteration: $iteration\t\t Property: $best_property_representation")
        # @show best_property_score
        push!(heuristic_properties, best_property)
        deleteat!(properties, best_property_index)
    end

    println("No solution found :(")

    return nothing
end