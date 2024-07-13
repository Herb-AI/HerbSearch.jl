abstract type ParallelType end
abstract type ParallelThreads <: ParallelType end
abstract type ParallelNoThreads <: ParallelType end

abstract type MetaSearchIterator end
struct VanillaIterator{F1} <: MetaSearchIterator 
    iterator::ProgramIterator
    stopping_condition::F1
    problem::Problem
end
# TODO: Make specific types for each combinator type. That would be nice
struct SequenceCombinatorIterator <: MetaSearchIterator
    iterators::Vector{<:MetaSearchIterator}
end
struct ParallelCombinatorIterator <: MetaSearchIterator 
    combinator_type::Type{<:ParallelType}
    iterators::Vector{<:MetaSearchIterator}
end
include("combinators.jl")

# TODO : Move this away from here
LONGEST_RUNNING_ALG_TIME = 6  # Maximum time a vanilla algorithm can run
MAX_SEQUENCE_RUNNING_TIME = 8 # Max sequence running time in seconds


# input is grammar and problem
meta_grammar = @csgrammar begin
    # Question: Is it better to generate a function or a lambda?
    S = function f(input_problem::Problem, input_grammar::AbstractGrammar)
        generic_run(COMBINATOR)
    end
	problemExamples = input_problem.spec

    # MS is either an algorithm or a combinator
    MS = SimpleIterator
    MS = COMBINATOR
    MAX_DEPTH = 10

    # VLSN configuration
    vlsn_neighbourhood_size = 1 | 2

    # SA configuration
    sa_inital_temperature = 1 | 2 | 3 | 4 | 5 | 6 
    sa_temperature_decreasing_factor = 0.9 | 0.91 | 0.92 | 0.93 | 0.94 | 0.95 | 0.96 | 0.97 | 0.98 | 0.99 

    # TODO: Fix algorithm
    ALGORITHM = MHSearchIterator(input_grammar, :X, problemExamples, mean_squared_error, max_depth=MAX_DEPTH) |
                SASearchIterator(input_grammar, :X, problemExamples, mean_squared_error, initial_temperature = sa_inital_temperature, temperature_decreasing_factor = sa_temperature_decreasing_factor, max_depth=MAX_DEPTH) |
                VLSNSearchIterator(input_grammar, :X, problemExamples, mean_squared_error, neighbourhood_size = vlsn_neighbourhood_size) | 
                BFSIterator(input_grammar, :X, max_depth=4) | 
                DFSIterator(input_grammar, :X, max_depth=4)  
    SimpleIterator = VanillaIterator(ALGORITHM, STOPFUNCTION, input_problem)
    # A = ga,STOP
    # A = dfs,STOP
    # A = bfs,STOP
    # A = astar,STOP
    COMBINATOR = SequenceCombinatorIterator(ALIST)
    COMBINATOR = ParallelCombinatorIterator(ParallelThreads, ALIST)
    ALIST = [MS; MS]
    ALIST = [MS; ALIST]
    # SELECT = best | crossover | mutate
    STOPFUNCTION = (time, iteration, cost) -> time > sa_inital_temperature || ITERATION_STOP  # longer running time is max(sa_inital_temperature) which is 6
    ITERATION_STOP = iteration > VALUE
    # STOPTERM = OPERAND < VALUE
    # OPERAND = time | iteration | cost
    VALUE = 1000 | 2000 | 3000 | 4000 | 5000
    # VALUE = 10 * VALUE
end

function evaluate_meta_program(meta_expression, problem::Problem, grammar :: AbstractGrammar)
    # get the function (problem,examples) -> run program
    program = eval(meta_expression)
    # provide the problem and the grammar for that problem 
    return Base.@invokelatest program(problem, grammar)
end