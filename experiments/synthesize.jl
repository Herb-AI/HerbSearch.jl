function string_distance(expected_found)
    distance = 0

    for (expected, found) in expected_found
        if found == 0
            return Inf
        end
        distance += levenshtein!(found.str, expected.str)     
    end

    return distance / length(expected_found)
end

function string_evaluation(grammar, program, problem)    
    try
        return HerbBenchmarks.String_transformations_2020.interpret(program, grammar, problem)
    catch e
        if isa(e, BoundsError)
            return 0
        else
            rethrow(e)
        end
    end
end

function synth_program(problems::Vector, grammar::ContextSensitiveGrammar, benchmark, gr_key, name::String, max_iterations::Int)
    # iterator = HerbSearch.MHSearchIterator(grammar, gr_key, problems, string_distance, max_depth=20, evaluation_function=string_evaluation)
    iterator = HerbSearch.VLSNSearchIterator(grammar, gr_key, problems, string_distance,
        max_depth = 20,
        vlsn_neighbourhood_depth = 3, 
        initial_temperature = 3,
        evaluation_function=string_evaluation
    ) 
    # iterator = HerbSearch.SASearchIterator(grammar, gr_key, problems, string_distance, max_depth=10, initial_temperature=1, temperature_decreasing_factor=0.99, evaluation_function=string_evaluation) 

    count = 0

    for program ∈ iterator
        count += 1
        println("Iteration $count, program $program")

        solved = true

        
            for problem in problems
                try
                    actual_state = benchmark.interpret(program, grammar, problem)
                    objective_state = problem.out

                    if actual_state != objective_state
                        solved = false
                        break
                    end
                catch e
                    if isa(e, BoundsError)
                        solved = false
                        break
                    else
                        rethrow(e)
                    end
                end
            end

        if solved == true
            return true, program, count
        end

        if count == max_iterations
            return
        end
    end

    return false, Nothing, count
end

