function get_meta_grammar()

	meta_grammar = @csgrammar begin
		S = (problem, grammar) -> generic_run(COMBINATOR...;)
		GIVEN_GRAMMAR = grammar
		GIVEN_PROBLEM = problem
		MS = A
		MS = COMBINATOR
		MAX_DEPTH = 10

		# SA configuration
		sa_inital_temperature = |(1:5)
		sa_temperature_decreasing_factor = |(range(0.9, 1, 10))

		# VLSN configuration
		vlsn_enumeration_depth = |(3:4)

		ALGORITHM = get_mh_enumerator(problem.examples, HerbSearch.mean_squared_error) | 
								get_sa_enumerator(problem.examples, HerbSearch.mean_squared_error, sa_inital_temperature, sa_temperature_decreasing_factor)
								get_vlsn_enumerator(problem.examples, HerbSearch.mean_squared_error, vlsn_enumeration_depth)
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
	return meta_grammar
end

function evaluate_meta_program(meta_expression,problem, grammar)
	# get the function (problem,examples) -> run program
	program = eval(meta_expression)   
	# provide the problem and the grammar for that problem 
	return Base.@invokelatest program(problem, grammar)
end