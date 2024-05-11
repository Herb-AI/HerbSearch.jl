function test_algorithm(runner,max_time_to_run)

    SEPARATOR = repeat("=",30)
    start_symbol = :X

    AVERAGE_RUNS = 20
    runs = []
    for alg_run ∈ 1:AVERAGE_RUNS
        solved_problems = 0
        start_time = time()
        
        lk = ReentrantLock()
        # RUNS on test problems
        Threads.@threads for (problem_id,(problem, text)) ∈ collect(enumerate(problems_test))      
            error_on_array = HerbSearch.mean_squared_error
            mse_accumulator = mse_error_function
            
            mh_algorithm = runner(problem.spec, error_on_array)

            _, cost, _ = search_best(
                arithmetic_grammar,
                problem,
                start_symbol,
                enumerator=mh_algorithm,
                error_function=mse_accumulator,
                max_depth=10,
                max_time=max_time_to_run,
                allow_evaluation_errors=false
            )
            println("Run: $alg_run problem: $problem_id Code: $text Cost: $cost. From thread $(Threads.threadid())")
            if cost == 0
                lock(lk) do
                    solved_problems += 1
                end
            end
        end    
        push!(runs,solved_problems)

        duration = time() - start_time
        printstyled("Run: $alg_run solved_problems: $solved_problems\n"; color=:green)
        println("Time took is $duration")
        println(SEPARATOR)
    end


    average_solved_problems = Statistics.mean(runs)
    std_dev_solved_problems = Statistics.std(runs)

    printstyled("Solved problems array: $runs\n"; color=:red)
    println(SEPARATOR)
    print("Average solved problems is: ")
    printstyled("$average_solved_problems"; color=:red)
    println("/", length(problems_test))
    print("Stddev solved problems is: ")
    printstyled("$std_dev_solved_problems\n"; color=:red)
    println(SEPARATOR)
    return runs
end

function test_meta_algorithm()

    SEPARATOR = repeat("=",30)

    AVERAGE_RUNS = 20
    runs = []
    for alg_run ∈ 1:AVERAGE_RUNS
        solved_problems = 0
        start_time = time()
        
        lk = ReentrantLock()
        # RUNS on test problems
        Threads.@threads for (problem_id,(problem, text)) ∈ collect(enumerate(problems_test))      
            _, _, cost  = meta_alg(problem.spec)

            println("Run: $alg_run problem: $problem_id Code: $text Cost: $cost. From thread $(Threads.threadid())")
            if cost == 0
                lock(lk) do
                    solved_problems += 1
                end
            end
        end    
        push!(runs,solved_problems)

        duration = time() - start_time
        printstyled("Run: $alg_run solved_problems: $solved_problems\n"; color=:green)
        println("Time took is $duration")
        println(SEPARATOR)
    end


    average_solved_problems = Statistics.mean(runs)
    std_dev_solved_problems = Statistics.std(runs)

    printstyled("Solved problems array: $runs\n"; color=:red)
    println(SEPARATOR)
    print("Average solved problems is: ")
    printstyled("$average_solved_problems"; color=:red)
    println("/", length(problems_test))
    print("Stddev solved problems is: ")
    printstyled("$std_dev_solved_problems\n"; color=:red)
    println(SEPARATOR)
    return runs
end