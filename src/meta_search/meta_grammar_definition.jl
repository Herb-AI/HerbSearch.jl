abstract type CombinatorType end
abstract type SequenceCombinator <: CombinatorType end
abstract type ParallelThreadsCombinator <: CombinatorType end
abstract type ParallelNoThreadsCombinator <: CombinatorType end

abstract type MetaSearchIterator end
struct VannilaIterator{F1} <: MetaSearchIterator
	iterator::ProgramIterator
	stop_condition::F1
	problem::Problem
end
# TODO: Make specific types for each combinator type. That would be nice
struct CombinatorIterator <: MetaSearchIterator
	combinator_type::CombinatorType
	iterator::Vector{MetaSearchIterator}
end
include("combinators.jl")

# TODO : Move this away from here
LONGEST_RUNNING_ALG_TIME = 5
MAX_SEQUENCE_RUNNING_TIME = 8 # Max sequence running time in seconds

# include("combinators.jl")

# input is grammar and problem
meta_grammar = @csgrammar begin
	S = (problem::Problem) -> generic_run(COMBINATOR...;)
	# MS is either an algorithm or a combinator
	MS = SimpleIterator 
	MS = COMBINATOR
	MAX_DEPTH = 10

	# SA configuration
	sa_inital_temperature = |(1:5)
	sa_temperature_decreasing_factor = |(range(0.9, 1, 10))

	# VLSN configuration
	vlsn_enumeration_depth = 1|2
	
	# TODO: Fix algorithm
	ALGORITHM = get_mh_enumerator(problemExamples, HerbSearch.mean_squared_error) | 
				get_sa_enumerator(problemExamples, HerbSearch.mean_squared_error, sa_inital_temperature, sa_temperature_decreasing_factor) |
				get_vlsn_enumerator(problemExamples, HerbSearch.mean_squared_error, vlsn_enumeration_depth)
	SimpleIterator = VannilaIterator(ALGORITHM, STOPFUNCTION, problem)
	# A = ga,STOP
	# A = dfs,STOP
	# A = bfs,STOP
	# A = astar,STOP
	COMBINATOR = CombinatorIterator(Sequence, ALIST)
	COMBINATOR = CombinatorIterator(Parallel, ALIST)
	ALIST = [MS; MS]
	ALIST = [MS; ALIST]
	# SELECT = best | crossover | mutate
	STOPFUNCTION = (time, iteration, cost) -> time > BIGGEST_TIME
	ITERATION_STOP = iteration > VALUE
	# STOPTERM = OPERAND < VALUE
	# OPERAND = time | iteration | cost
	BIGGEST_TIME = 2 | 3 | 4 | 5
	VALUE = 1000 | 2000 | 3000 | 4000 | 5000
	# VALUE = 10 * VALUE
end

function evaluate_meta_program(meta_expression,problem, grammar)
	# get the function (problem,examples) -> run program
	program = eval(meta_expression)   
	# provide the problem and the grammar for that problem 
	return Base.@invokelatest program(problem.spec, grammar)
end