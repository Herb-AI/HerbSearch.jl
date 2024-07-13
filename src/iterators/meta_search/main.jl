using HerbInterpret
using HerbGrammar
using HerbSpecification
using HerbConstraints
using HerbSearch
using Logging

import Random

include("configuration.jl")

"""
    meta_search_fitness_function(program)

The fitness function used for a given program from the meta-grammar.
To evaluate a possible combinator/algorithm for the meta-search we don't have access any input and outputs examples.

The current fitness is given by:
```julia
1 / (mean_cost * 100 + mean_running_time)
```

"""
function meta_search_fitness_function(program)
    expression_to_evaluate = rulenode2expr(program, meta_grammar)

    # evaluate the search 3 times to account for variable time of running a program
    RUNS = fitness_configuration.number_of_runs_to_average_over

    mean_cost = 0
    mean_running_time = 0

    lk = Threads.ReentrantLock()
    Threads.@threads for i ∈ eachindex(HerbSearch.problems_train)
        (problem, problem_text) = HerbSearch.problems_train[i]
        for _ in 1:RUNS
            # get a program that needs a problem and a grammar to be able to run
            output = @timed best_program, program_cost = evaluate_meta_program(expression_to_evaluate, problem, HerbSearch.arithmetic_grammar)
            
            lock(lk) do
                mean_cost += program_cost
                mean_running_time += output.time
            end
        end
    end

    # print("Program has depth: ", depth(program))

    mean_cost /= (length(HerbSearch.problems_train) * RUNS)
    mean_running_time /= (length(HerbSearch.problems_train) * RUNS)
    fitness_value = 1 / (mean_cost * 100 + mean_running_time)
    return fitness_value
end


"""
    run_meta_search(stopping_condition)

Runs meta search with the stopping condition. 
"""
function run_meta_search_with_genetic(; max_time::Int64, max_iterations::Int64)
    # creates a genetic enumerator with no examples and with the desired fitness function 
    println("Creating initial population with random programs of maxdepth $(genetic_configuration.initial_population_size)")
    genetic_iterator = GeneticSearchIterator(
        meta_grammar, :S,
        Vector{IOExample}(),
        maximum_initial_population_depth = genetic_configuration.initial_program_max_depth,
        population_size          = genetic_configuration.initial_population_size,
        use_threads              = true
    )

    # run the meta search
    @time best_program, best_fitness = meta_search(genetic_iterator, meta_grammar, max_time = max_time, max_iterations = max_iterations)

    # get the meta_program found so far.
    println("Best meta program is :", best_program)
    println("Best fitness found :", best_fitness)
    return best_program
end


function get_meta_algorithm()
    Logging.disable_logging(Logging.LogLevel(Logging.Info))
    print_meta_configuration()

    @time output = run_meta_search_with_genetic(max_time=typemax(Int), max_iterations=200)
    println("Output of meta search is: ", output)
    return output
end

Random.seed!(1)
# overwrite genetic fitness function with the meta search fitness
HerbSearch.fitness(::GeneticSearchIterator, program::RuleNode, results::AbstractVector{<:Tuple{Any,Any}}) = meta_search_fitness_function(program)
get_meta_algorithm()