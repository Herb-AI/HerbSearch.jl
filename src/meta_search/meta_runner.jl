using HerbCore
using HerbGrammar
using HerbData
using HerbSearch
using Logging

# TODO Supercomputer: Create some good logging for the meta search. Don't just use println
disable_logging(LogLevel(1))

using Base.Threads
include("combinators.jl")


arithmetic_grammar = @csgrammar begin
    X = |(1:5)
    X = X * X
    X = X + X
    X = X - X
    X = x
end

# CREATE A PROBLEM
function create_problem(f, range=5)
    examples = [HerbData.IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
    return HerbData.Problem(examples), examples
end

# TODO Generalize: Define more problems to evaluate the meta-program on.
problem, examples = create_problem(x -> x^4 + x * x + 2 * x + 5)

# TODO Refactor: Export the meta grammar to a different file. We can't do that untill there is a quick fix in HerbGrammar.jl
meta_grammar = @csgrammar begin
    S = generic_run(COMBINATOR...;)
    MS = A
    MS = COMBINATOR
    MAX_DEPTH = 8
    sa_inital_temperature = |(1:5)
    # range from splits the range from [0.9,1] and generates 10 numbers with equal distance to each other
    sa_temperature_decreasing_factor = |(range(0.9, 1, 10))
    vlsn_enumeration_depth = |(2:3)
    GIVEN_GRAMMAR = arithmetic_grammar
    GIVEN_PROBLEM = problem
    ALGORITHM = mh() | sa(sa_inital_temperature, sa_temperature_decreasing_factor) | vlsn(vlsn_enumeration_depth)
    A = (ALGORITHM, STOPFUNCTION, MAX_DEPTH, GIVEN_PROBLEM, GIVEN_GRAMMAR)
    # A = ga,STOP
    # A = dfs,STOP
    # A = bfs,STOP
    # A = astar,STOP
    # MHCONFIGURATION = MAXDEPTH
    # MAXDEPTH = 3
    COMBINATOR = (Sequence, ALIST, MAX_DEPTH, GIVEN_GRAMMAR)
    COMBINATOR = (Parallel, ALIST, MAX_DEPTH, GIVEN_GRAMMAR)
    ALIST = [MS; MS]
    ALIST = [MS; ALIST]
    # COMBINATOR = sequence(MSLIST)
    # COMBINATOR = parallel([MSLIST],SELECT)
    # MSLIST = MS,MS
    # MSLIST = MS,MSLIST
    # SELECT = best | crossover | mutate
    STOPFUNCTION = (time, iteration, cost) -> STOPCONDITION
    STOPCONDITION = STOPTERM
    STOPCONDITION = STOPTERM && STOPCONDITION
    # STOPTERM = OPERAND == VALUE
    STOPTERM = ITERATION_STOP
    ITERATION_STOP = iteration > VALUE
    # STOPTERM = OPERAND < VALUE
    # OPERAND = time | iteration | cost
    OPERAND = iteration
    VALUE = |(4000:5000)
    # VALUE = 10 * VALUE
end


mh() = get_mh_enumerator(examples, HerbSearch.mean_squared_error)
sa(inital_temperature, temperature_decreasing_factor) = get_sa_enumerator(examples, HerbSearch.mean_squared_error, inital_temperature, temperature_decreasing_factor)
vlsn(enumeration_depth) = get_vlsn_enumerator(examples, HerbSearch.mean_squared_error, enumeration_depth)

"""
    Function that is used for testing the meta_grammar. It generates a random meta_program 10 times and evaluates it.
"""
function run_grammar_multiple_times()
    for _ in 1:100
        meta_program = rand(RuleNode, meta_grammar, :S, 10)
        meta_expr = rulenode2expr(meta_program, meta_grammar)
        @time expr, _, _ = eval(meta_expr)
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
    expression = rulenode2expr(program, meta_grammar)

    # evaluate the search 3 times to account for variable time of running a program
    RUNS = 3

    mean_cost = 0
    mean_running_time = 0

    # Nick:
    # TODO Performance: Is SpinLock good in this case? Maybe use atomic instructions
    # TODO Performance: Ask Sebastijan if we should do this runs for non stochastic algorithms. Maybe we should not do that.

    # use a sping lock because the update should be very fast. This prevents race conditions in mean_cost
    lk = Threads.ReentrantLock()
    Threads.@threads for _ in 1:RUNS
        start_time = time()
        _, _, cost = eval(expression)
        duration = time() - start_time
        lock(lk) do
            mean_cost += cost
            mean_running_time += duration
        end
    end

    mean_cost = mean_cost / RUNS
    mean_running_time = mean_running_time / RUNS

    # TODO Experiment: Try different formulas here to experiment
    final_cost = 1 / (mean_cost * 100 + mean_running_time)

    if final_cost > 1
        println("A program reached cost: $mean_cost in time: $mean_running_time => $final_cost")
    end
    # println("====================\n")
    return final_cost
end


# TODO Refactor: Don't hardcode value 10 as the value for the population, make it a configurable param maybe.
"""
    genetic_state(; current_program::RuleNode)

Is called by `supervised_search` and returns the genetic state that will be created from an initial program.
It just duplicates the program 10 times and pus that into the start population.
"""
genetic_state(; current_program::RuleNode) = HerbSearch.GeneticIteratorState([current_program for i ∈ 1:10])

"""
    run_meta_search()

Runs meta search on the meta grammar.
"""
function run_meta_search()
    # create a random meta_program to start with that has max_depth 10
    meta_program = rand(RuleNode, meta_grammar, :S, 10)

    # creates a genetic enumerator with no examples and with the desired fitness function 
    genetic_algorithm = get_genetic_enumerator(Vector{Example}([]), fitness_function=fitness_function)

    # run the meta search
    @time best_program, best_fitness = meta_search(
        meta_grammar, :S,
        stopping_condition = (time, iteration, fitness) -> iteration >= 15,
        start_program = meta_program,
        enumerator = genetic_algorithm,
        state = genetic_state
    )

    # get the meta_program found so far.
    println("Best meta program is :", best_program)
    println("Best fitness found :", best_fitness)

end

run_meta_search()