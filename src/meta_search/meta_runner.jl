using Base.Threads
using Configurations

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

convert_string_to_lambda(e::String) = eval(Meta.parse(e))


meta_configuration = from_toml(MetaConfiguration, "configuration.toml")
fitness_configuration = meta_configuration.fitness
genetic_configuration = meta_configuration.genetic

println("CONFIGURATION")
println("- Number of available threads: ",Threads.nthreads())
print("- ")
dump(meta_configuration)
println("=========================================")
@show meta_grammar
println("=========================================")
println("Genetic algorithm always adds the best program so far in the population")

"""
    Function that is used for testing the meta_grammar. It generates a random meta_program 10 times and evaluates it.
"""
function run_grammar_multiple_times()
    for _ in 1:100
        for (problem, _) ∈ problems_train
            meta_program = rand(RuleNode, meta_grammar, :S, 10)
            meta_expr = rulenode2expr(meta_program, meta_grammar)
            # print(meta_expr)
            # get a program that needs a problem and a grammar to be able to run
            @time expr,cost = evaluate_meta_program(meta_expr, problem, arithmetic_grammar)
            print(expr,"",cost)
        end
    end
end

filename = "run-$(abs(rand(Int16)))"
dirpath = joinpath(@__DIR__, "data")
mkpath(dirpath)
file_path = joinpath(dirpath, filename)
println("filename is: $filename")
io = open(file_path, "a");


"""
    fitness_function(program, array_of_outcomes)

The fitness function used for a given program from the meta-grammar.
To evaluate a possible combinator/algorithm for the meta-search we don't have access any input and outputs examples.
We just the have the program itself (a combinator). 
For instance how would you evaluate how well the program `sequence(mh(some_params), sa(some_other_params))` behaves?
There are no input/output examples here, we just run the algorithm and see how far can we get. Thus, the second
parameter (`array_of_outcomes`) is ignored by use of _ in julia.

To evaluate how well the a given combinator works I look at the time it takes to complete and the final cost it reaches.
Because higher fitness means better I invert the fraction usint 1 / (cost * 100 + duration).
The 100 just gives more weight to the cost I think. You can chose another value.
"""
function fitness_function(program, _)
    expression_to_evaluate = rulenode2expr(program, meta_grammar)

    # evaluate the search 3 times to account for variable time of running a program
    RUNS = fitness_configuration.number_of_runs_to_average_over

    mean_cost = 0
    mean_running_time = 0

    lk = Threads.SpinLock()
    for i ∈ eachindex(problems_train)
        (problem,problem_text) = problems_train[i]
        mean_cost_for_problem = 0
        mean_running_time_for_problem = 0   

        Threads.@threads for _ in 1:RUNS
            
            # get a program that needs a problem and a grammar to be able to run
            output = @timed best_expression, best_program, program_cost = evaluate_meta_program(expression_to_evaluate, problem, arithmetic_grammar)
            write(io,"$problem_text -> duration: $(output.time), gc: $(output.gctime) cost: $program_cost\n")
            flush(io)
            lock(lk) do
                mean_cost_for_problem += program_cost
                mean_running_time_for_problem += output.time
            end
        end

        lock(lk) do 
            mean_cost_for_problem = mean_cost_for_problem / RUNS
            mean_running_time_for_problem = mean_running_time_for_problem / RUNS    
            
            mean_cost += mean_cost_for_problem
            mean_running_time += mean_running_time_for_problem
        end
    end
    mean_cost /= length(problems_train)
    mean_running_time /= length(problems_train)
    fitness_value = 1 / (mean_cost * 100 + mean_running_time)
    return fitness_value
end


"""
    run_meta_search()

Runs meta search on the meta grammar.
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





# run_meta_search(meta_grammar, nothing)
# run_grammar_multiple_times()