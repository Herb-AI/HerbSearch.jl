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
		@test decide_if_solution(problem1, expr, symboltable) == true
		@test decide_if_solution(problem2, expr, symboltable) == false
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

		# TODO: add subproblem with two IOExamples
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

		ioexamples_solutions = [
			(IOExample(Dict(:_arg_1 => 1, :_arg_2 => 2), 2), [RuleNode(6)]),
			(IOExample(Dict(:_arg_1 => 3, :_arg_2 => 0), 3), [RuleNode(3)]),
			(
				IOExample(Dict(:_arg_1 => -3, :_arg_2 => 0), 0),
				[
					RuleNode(
						2,
						[RuleNode(9, [RuleNode(3), RuleNode(5)]), RuleNode(5), RuleNode(3)],
					),
					RuleNode(5),
					RuleNode(3),
				],
			),
			(
				IOExample(Dict(:_arg_1 => 1, :_arg_2 => 1), 1),
				[RuleNode(8, [RuleNode(5), RuleNode(6)]), RuleNode(4)],
			),
		]

		# convert expected labels to set => no guarantee of order in vec_problems_solutions
		@testset verbose = true "labels" begin
			expected_labels = Set([
				"6,",
				"3,",
				"2{9{3,5}5,3}",
				"8{5,6}",
			])
			labels, labels_to_programs = HerbSearch.get_labels(ioexamples_solutions)
			@test length(labels) == 4
			@test Set(labels) == expected_labels
		end

		@testset verbose = true "predicates" begin
			n_predicates = 100
			sym_bool = :Condition
			sym_constraint = :Input
			predicates = HerbSearch.get_predicates(grammar, sym_bool, sym_constraint, n_predicates)
			idx_rule = grammar.bytype[sym_constraint][1]
			@test length(predicates) == n_predicates
			# pick a few random predicates and check if they contain rule we expect
			@test !isempty(rulesoftype(predicates[23], Set([idx_rule])))
			@test !isempty(rulesoftype(predicates[99], Set([idx_rule])))
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

			expected_features =
				BitArray([true false true; false true false; true false false; true true true])
			features = HerbSearch.get_features(
				ioexamples_solutions,
				predicates, grammar, symboltable,
			)
			@test features == expected_features
			# TODO: When do I get EvaluationError?
			@test_throws HerbSearch.EvaluationError HerbSearch.get_features(
				ioexamples_solutions,
				[RuleNode(11, [RuleNode(4)])], # ehad_cvc(_arg_1)
				grammar,
				symboltable,
				false,
			)
			ioexamples = [(key.spec, sol) for (key, sol) in problems_to_solutions]
			ioexamples = Vector{Tuple{IOExample, Vector{RuleNode}}}()
			for (key, sol) in problems_to_solutions
				for example in key.spec
					push!(ioexamples, (example, sol))
				end
			end
			ioexamples =
				[(example, sol) for (key, sol) in problems_to_solutions for example in key.spec]


		end
		@testset verbose = true "Construct final program" begin
			# TODO: define a very simple grammar
			# TODO: define a decision tree
			# TODO: call function with root of decision tree as first node

			# function construct_final_program(
			# 	node::Union{DecisionTree.Node, DecisionTree.Leaf},
			# 	idx_ifelse::Int64,
			# 	labels_to_programs::Dict{String, Union{StateHole, RuleNode}},
			# 	predicates::Vector{RuleNode},
			# )::RuleNode
		end
	end

	# TODO: Integration test for divide and conquer search procedure
end
