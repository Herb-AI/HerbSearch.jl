

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
    heuristic_properties_reprs = []

    for iteration in 1:max_iterations

        # Perform beam search
        function heuristic(rulenode, child_values)
            outputs = rulenode._val

            if any(isnothing, outputs)
                return Inf
            end

            cost = 0
            for p in heuristic_properties
                target_values = p(target_outputs)
                values = p(outputs)
                
                cost += sum(target_values .!= values)
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
                return beam_entry.program, heuristic_properties_reprs
            end
        end

        # Otherwise; find the property that adds the most heuristic cost to the last beam
        beam_outputs = [beam_entry.program._val for beam_entry in iterator.beam]

        best_property = nothing
        best_property_index = 0
        best_property_representation = nothing
        best_property_score = -Inf
        best_possible_score = count(output != target_output for outputs in beam_outputs for (output, target_output) in zip(outputs, target_outputs))

        for (property_index, (property, representation)) in enumerate(properties)
            target_values = property(target_outputs)

            # if !allequal(target_values)
            #     continue
            # end

            score = 0

            for beam_entry_outputs in beam_outputs
                values = property(beam_entry_outputs)
                score += sum(target_values .!= values)
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
        println("\nIteration:\t $iteration\t\t Best score: $best_property_score/$best_possible_score\t\t Best property: $best_property_representation")
        # target_values = best_property(target_outputs)
        # println("Target values:\t$target_values")

        # for entry in iterator.beam
        #     p = rulenode2expr(entry.program, grammar)
        #     values = best_property(entry.program._val)

        #     println("\t$(entry.cost) \t\t $(entry.program._val)\t\t $p")
        #     println("\t$values")
        # end
        println("Best outputs\t $(beam_outputs[1])")
        println("Best cost\t $(iterator.beam[1].cost)")
        expr = rulenode2expr(iterator.beam[1].program, grammar)
        println("Best program\t $expr")
        push!(heuristic_properties, best_property)
        push!(heuristic_properties_reprs, best_property_representation)
        deleteat!(properties, best_property_index)
    end

    println("No solution found :(")

    return nothing, heuristic_properties_reprs
end