using Base.Threads
using Configurations
using HerbCore

include("meta_arithmetic_grammar.jl")
include("meta_grammar_definition.jl")


@option struct GeneticConfiguration 
    initial_population_size::Int64
    initial_program_max_depth::Int64
end

@option struct FitnessFunctionConfiguration 
    number_of_runs_to_average_over::Int16
end


@option struct MetaConfiguration
    fitness::FitnessFunctionConfiguration
    genetic::GeneticConfiguration
end

meta_configuration::MetaConfiguration = from_toml(MetaConfiguration, "src/meta_search/configuration.toml")
fitness_configuration = meta_configuration.fitness
genetic_configuration = meta_configuration.genetic



"""
    fitness_function(program, array_of_outcomes)

The fitness function used for a given program from the meta-grammar.
To evaluate a possible combinator/algorithm for the meta-search we don't have access any input and outputs examples.

The current fitness is given by:
```julia
1 / (mean_cost * 100 + mean_running_time)
```

"""
function fitness_function(program, _)
    expression_to_evaluate = rulenode2expr(program, meta_grammar)

    # evaluate the search 3 times to account for variable time of running a program
    RUNS = fitness_configuration.number_of_runs_to_average_over

    mean_cost = 0
    mean_running_time = 0

    lk = Threads.ReentrantLock()
    for i ∈ eachindex(problems_train)
        (problem,problem_text) = problems_train[i]
        for _ in 1:RUNS
            
            # get a program that needs a problem and a grammar to be able to run
            output = @timed best_expression, best_program, program_cost = evaluate_meta_program(expression_to_evaluate, problem, arithmetic_grammar)
            
            lock(lk) do
                mean_cost += program_cost
                mean_running_time += output.time
            end
        end
    end

    print("Program has depth: ", depth(program))

    mean_cost /= (length(problems_train) * RUNS)
    mean_running_time /= (length(problems_train) * RUNS)
    fitness_value = 1 / (mean_cost * 100 + mean_running_time)
    return fitness_value
end



"""
    run_meta_search(stopping_condition)

Runs meta search with the stopping condition. 
"""
function run_meta_search(stopping_condition:: Union{Nothing, Function})
    # creates a genetic enumerator with no examples and with the desired fitness function 
    println("Creating initial population with random programs of maxdepth $(genetic_configuration.initial_population_size)")
    genetic_algorithm = get_genetic_enumerator(Vector{IOExample}([]), 
        fitness_function=fitness_function,
        maximum_initial_population_depth = genetic_configuration.initial_program_max_depth,
        initial_population_size          = genetic_configuration.initial_population_size
    )

    # run the meta search
    @time best_program, best_fitness = meta_search(
        meta_grammar, 
        :S,
        stopping_condition = stopping_condition,
        enumerator = genetic_algorithm,
    )

    # get the meta_program found so far.
    println("Best meta program is :", best_program)
    println("Best fitness found :", best_fitness)
    return best_program
end
