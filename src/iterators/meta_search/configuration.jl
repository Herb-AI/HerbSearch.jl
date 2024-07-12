using Configurations

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

function read_configuration()
    global meta_configuration = from_toml(MetaConfiguration, "src/iterators/meta_search/configuration.toml")
    global fitness_configuration = meta_configuration.fitness
    global genetic_configuration = meta_configuration.genetic
end

function print_meta_configuration()
    read_configuration()
    println("CONFIGURATION")
    println("- Number of available threads: ", Threads.nthreads())
    println("- Maximum sequence running time: $(HerbSearch.MAX_SEQUENCE_RUNNING_TIME)")
    println("- Longest time maximum given to an algorithm: $(HerbSearch.LONGEST_RUNNING_ALG_TIME)")

    dump(meta_configuration)
    println("=========================================")
    @show HerbSearch.meta_grammar # it is included in another file
    println("=========================================")
    println("Genetic algorithm always adds the best program so far in the population")
    
end