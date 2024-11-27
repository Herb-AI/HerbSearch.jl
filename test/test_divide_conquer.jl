@testset verbose = true "Search procedure divide and conquer" begin
	@test 1 == 2 # TODO: failing test is just a reminder to add actually useful tests.

	@testset verbose = true "divide, stopping criteria" begin
		problem = Problem([IOExample(Dict(), x) for x ∈ 1:3])
		expected_subproblems = [
			Problem([IOExample(Dict(), 1)]),
			Problem([IOExample(Dict(), 2)]),
			Problem([IOExample(Dict(), 3)]),
		]
		subproblems = divide_by_example(problem)
		# TODO: test equality

		# Stopping criteria: stop search once we have a solution to each subproblem
		problems_to_solutions::Dict{Problem, Vector{RuleNode}} = Dict(p => [] for p in subproblems)

		push!(problems_to_solutions[subproblems[1]], RuleNode(3))
		@test all(!isempty, values(problems_to_solutions)) == false

		push!(problems_to_solutions[subproblems[1]], RuleNode(4))
		push!(problems_to_solutions[subproblems[2]], RuleNode(3))
		@test all(!isempty, values(problems_to_solutions)) == false

		push!(problems_to_solutions[subproblems[3]], RuleNode(3))
		@test all(!isempty, values(problems_to_solutions)) == true
	end

	@testset verbose = true "decide" begin
		grammar = @csgrammar begin
			Number = |(1:2)
			Number = x
			Number = Number + Number
			Number = Number * Number
		end
		symboltable = SymbolTable(grammar)
		problem1 = Problem([IOExample(Dict(:x => 1), 3)])
		problem2 = Problem([IOExample(Dict(:x => 1), 4)])
		program = RuleNode(4, [RuleNode(3), RuleNode(2)])
		expr = rulenode2expr(program, grammar)
		@test decide_if_solution(problem1, program, expr, symboltable) == true
		@test decide_if_solution(problem2, program, expr, symboltable) == false
	end

	@testset verbose = true "conquer" begin
		grammar = @csgrammar begin
			Start = Integer
			Integer = Condition ? Integer : Integer
			Integer = 0
			Integer = 1
			Input = _arg_1
			Input = _arg_2
			Integer = Input
			Integer = Integer + Integer
			Condition = Integer <= Integer
			Condition = Condition && Condition
			Condition = !Condition
		end

		symboltable = SymbolTable(grammar)

		subproblems = [
			Problem([IOExample(Dict(:_arg_1 => 1, :_arg_2 => 2), 2)]),
			Problem([IOExample(Dict(:_arg_1 => 3, :_arg_2 => 0), 3)]),
			Problem([IOExample(Dict(:_arg_1 => -3, :_arg_2 => 0), 0)]),
			Problem([IOExample(Dict(:_arg_1 => 1, :_arg_2 => 1), 1)]),
		]
		problems_to_solutions::Dict{Problem, Vector{RuleNode}} = Dict(p => [] for p in subproblems)
		push!(problems_to_solutions[subproblems[1]], RuleNode(6))
		push!(problems_to_solutions[subproblems[2]], RuleNode(3))
		push!(
			problems_to_solutions[subproblems[3]],
			RuleNode(2, [RuleNode(9, [RuleNode(3), RuleNode(5)]), RuleNode(5), RuleNode(3)]),
		)
		push!(problems_to_solutions[subproblems[4]], RuleNode(8, [RuleNode(5), RuleNode(6)]))
		push!(problems_to_solutions[subproblems[4]], RuleNode(4))
		# solution program for subproblems[3]
		# if 0 <= _arg_1
		#    _arg_1
		# else
		#    0
		# RuleNode(2, [RuleNode(9, [RuleNode(3), RuleNode(5)]), RuleNode(5), RuleNode(3)])

		# convert dict to vector for getting labels and features
		vec_problems_solutions = [(prob, sol) for (prob, sol) in problems_to_solutions]
		# convert expected labels to set => no guarantee of order in vec_problems_solutions
		@testset verbose = true "labels" begin
			expected_labels = Set([
				"6,",
				"3,",
				"2{9{3,5}5,3}",
				"8{5,6}",
			])
			labels = HerbSearch.get_labels(vec_problems_solutions)
			@test length(labels) == 4
			@test Set(labels) == expected_labels
		end
		@testset verbose = true "predicates" begin
			n_predicates = 100
			sym_bool = :Condition
			predicates = HerbSearch.get_predicates(grammar, sym_bool, n_predicates)
			@test length(predicates) == n_predicates
		end
		@testset verbose = true "features" begin
			predicates = [
				RuleNode(9, [RuleNode(5), RuleNode(6)]),
				RuleNode(9, [RuleNode(6), RuleNode(5)]),
				RuleNode(
					10,
					[
						RuleNode(9, [RuleNode(5), RuleNode(6)]),
						RuleNode(9, [RuleNode(4), RuleNode(6)]),
					],
				),
			]

			expressions = [rulenode2expr(p, grammar) for p in predicates]
			expected_expressions =
				[:(_arg_1 <= _arg_2), :(_arg_2 <= _arg_1), :(_arg_1 <= _arg_2 && 1 <= _arg_2)]
			@test expressions == expected_expressions

			# TODO: 
			expected_features =
				BitArray([true false true; false true false; true false false; true true true])
			# features = HerbSearch.get_features(
			# 	vec_problems_solutions,
			# 	predicates, grammar, symboltable,
			# )
			# -----------| debug | ------------
			features = trues(length(vec_problems_solutions),
				length(predicates))
			println("Dimension features: ", size(features))
			for (i, (prob, _)) in enumerate(vec_problems_solutions) # TODO: make this work on vec
				output = Vector()
				for pred in predicates
					expr = rulenode2expr(pred, grammar)
					println("Expression: ", expr)
					println("Problem: ", prob.spec)
					try
						println("Problem: ", prob.in)
						# o = execute_on_input(symboltable, expr, prob.in) # will return Bool since we execute on predicates
						# 			push!(output, o)
					catch err
						# 			# TODO: do we understand this part? Do we expect evaluation errors?
						# 			# Throw the error if evaluation errors aren't allowed
						# 			# eval_error = EvaluationError(expr, e.in, err)
						# 			# allow_evaluation_errors || throw(eval_error)
						# 			println("Error: ", err)
						# 			push!(output, false)
						# 			# break
					end
				end
				# 	features[i, :] = output
			end
			# ---------------------------------
			# TODO: test   

			# TODO: test with evaluaiton error
		end
	end

	# TODO: Integration test for divide and conquer search procedure
end
