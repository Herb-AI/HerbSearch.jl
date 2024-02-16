using HerbCore
using HerbGrammar
using HerbData
using HerbSearch
using Logging
using Configurations

# TODO Supercomputer: Create some good logging for the meta search. Don't just use println
disable_logging(LogLevel(1))

using Base.Threads
include("combinators.jl")
include("meta_grammar_definition.jl")



@option struct GeneticConfiguration 
    initial_population_size::Int16
    initial_program_max_depth::Int64
    stopping_condition::String
end

@option struct FitnessFunctionConfiguration 
    number_of_runs_to_average_over::Int16
    fitness_function::String
end

@option struct MetaGrammarConfiguration 
    maximum_depth::Int
end

@option struct MetaConfiguration
    problem_expression::String
    problem_range_size::Int64
    fitness::FitnessFunctionConfiguration
    genetic::GeneticConfiguration
    meta_grammar::MetaGrammarConfiguration
end

convert_string_to_lambda(e::String) = eval(Meta.parse(e))


meta_configuration = from_toml(MetaConfiguration, "configuration.toml")
fitness_configuration = meta_configuration.fitness
genetic_configuration = meta_configuration.genetic
meta_grammar_configuration = meta_configuration.meta_grammar

fitnes_cost_function = convert_string_to_lambda(fitness_configuration.fitness_function)

println("CONFIGURATION")
println("- Number of available threads: ",Threads.nthreads())
print("- ")
dump(meta_configuration)
println("=========================================")

arithmetic_grammar = @csgrammar begin
    X = |(1:5)
    X = X * X
    X = X + X
    X = X - X
    X = x
end

# CREATE A PROBLEM
function create_simple_problem(f)
    examples = [HerbData.IOExample(Dict(:x => x), f(x)) for x ∈ 1:meta_configuration.problem_range_size]
    return HerbData.Problem(examples)
end

# TODO Generalize: Define more problems to evaluate the meta-program on.
arithmetic_problem = create_simple_problem(convert_string_to_lambda(meta_configuration.problem_expression))
meta_grammar = get_meta_grammar()
list_of_problems = [(arithmetic_problem, meta_grammar)]



"""
    Function that is used for testing the meta_grammar. It generates a random meta_program 10 times and evaluates it.
"""
function run_grammar_multiple_times()
    for _ in 1:100
        for (problem,grammar) ∈ list_of_problems
            meta_program = rand(RuleNode, meta_grammar, :S, 10)
            meta_expr = rulenode2expr(meta_program, meta_grammar)
            print(meta_expr)
            # get a program that needs a problem and a grammar to be able to run
            @time expr,_,_ = evaluate_meta_program(meta_expr,problem, grammar)
        end
        # return
        # @time expr, _, _ = eval(meta_expr)
    end
end

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
    program_to_evaluate = rulenode2expr(program, meta_grammar)

    # evaluate the search 3 times to account for variable time of running a program
    RUNS = fitness_configuration.number_of_runs_to_average_over

    mean_cost = 0
    mean_running_time = 0
    # TODO: Switch to btime maybe
    # Nick:
    # TODO Performance: Is SpinLock good in this case? Maybe use atomic instructions
    # TODO Performance: Ask Sebastijan if we should do this runs for non stochastic algorithms. Maybe we should not do that.

    # use a sping lock because the update should be very fast. This prevents race conditions in mean_cost
    # TODO: use loop of indexes
    lk = Threads.ReentrantLock()
    for (problem,grammar) ∈ list_of_problems
        mean_cost_for_problem = 0
        mean_running_time_for_problem = 0    
        for _ in 1:RUNS
            start_time = time()
            _, _, cost = evaluate_meta_program(program_to_evaluate, problem, grammar)
            duration = time() - start_time
            lock(lk) do
                mean_cost_for_problem += cost
                mean_running_time_for_problem += duration
            end
        end
        mean_cost_for_problem = mean_cost_for_problem / RUNS
        mean_running_time_for_problem = mean_running_time_for_problem / RUNS    
        
        mean_cost += mean_cost_for_problem
        mean_running_time += mean_running_time_for_problem
    end
    mean_cost /= length(list_of_problems)
    mean_running_time /= length(list_of_problems)


    fitness_value = fitnes_cost_function(mean_cost, mean_running_time)
    return fitness_value
end


"""
    genetic_state(; current_program::RuleNode)

Is called by `supervised_search` and returns the genetic state that will be created from an initial program.
It just duplicates the program 10 times and pus that into the start population.
"""
genetic_state(; current_program::RuleNode) = HerbSearch.GeneticIteratorState([current_program for i ∈ 1:genetic_configuration.initial_population_size])

"""
    run_meta_search()

Runs meta search on the meta grammar.
"""
function run_meta_search(meta_grammar, stopping_condition:: Union{Nothing, Function})
    meta_program = rand(RuleNode, meta_grammar, :S, genetic_configuration.initial_program_max_depth)

    # creates a genetic enumerator with no examples and with the desired fitness function 
    genetic_algorithm = get_genetic_enumerator(Vector{Example}([]), fitness_function=fitness_function)

    function_to_run = isnothing(stopping_condition) ? convert_string_to_lambda(genetic_configuration.stopping_condition) : stopping_condition 
    # run the meta search
    @time best_program, best_fitness = meta_search(
        meta_grammar, :S,
        stopping_condition = function_to_run,
        start_program = meta_program,
        enumerator = genetic_algorithm,
        state = genetic_state
    )

    # get the meta_program found so far.
    println("Best meta program is :", best_program)
    println("Best fitness found :", best_fitness)

end

filename = "run.csv"
dirpath = joinpath(@__DIR__, "data")
mkpath(dirpath)

file_path = joinpath(dirpath, filename)
open(file_path, "w") do file
    write(file_path, "Hello world!")
end

run_meta_search(meta_grammar, nothing)
# run_grammar_multiple_times()