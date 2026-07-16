DivideAndConquerExt = Base.get_extension(HerbSearch, :DivideAndConquerExt)
using .DivideAndConquerExt: conquer

# `conquer` fits a DecisionTreeClassifier on a fixed budget of BFS-enumerated
# predicates and turns the tree straight into an if-else program. If that
# predicate budget cannot tell two examples apart that need different
# sub-programs, both land in the same leaf, and the leaf can only hold one
# program: majority vote picks one, and the other example silently gets the
# wrong program.
#
# 1 predicate gives a decision tree at most 2 leaves (one split). This test
# has 3 groups of examples that each need a different sub-program, so no
# matter which single predicate BFS happens to try first, at least two groups
# must share a leaf. This is not bad luck we're checking for; it is
# impossible to avoid with only 1 predicate, which is exactly why it is a
# reliable test.
@testset verbose = true "conquer never returns an unverified program" begin
	grammar = @csgrammar begin
		Integer = |(0:5)
		Input = _arg_1
		Integer = Input
		Integer = Integer + Integer
		Integer = Integer - Integer
		Condition = Integer <= Integer
		Integer = Condition ? Integer : Integer
	end
	sym_bool = :Condition
	sym_start = :Integer
	sym_constraint = :Input
	interp = HerbInterpret.make_interpreter(grammar; target_module = Main, cache_module = Main)

	input_rn = RuleNode(8, [RuleNode(7)]) # Input
	prog_plus_one   = RuleNode(9, [input_rn, RuleNode(2)])           # _arg_1 + 1
	prog_minus_five = RuleNode(10, [input_rn, RuleNode(6)])          # _arg_1 - 5
	prog_double     = RuleNode(9, [input_rn, deepcopy(input_rn)])    # _arg_1 + _arg_1
	solutions = [prog_plus_one, prog_minus_five, prog_double]

	examples = [
		(Problem([IOExample(Dict(:_arg_1 => 1), 2)]), 1),
		(Problem([IOExample(Dict(:_arg_1 => 2), 3)]), 1),
		(Problem([IOExample(Dict(:_arg_1 => 5), 0)]), 2),
		(Problem([IOExample(Dict(:_arg_1 => 6), 1)]), 2),
		(Problem([IOExample(Dict(:_arg_1 => 10), 20)]), 3),
		(Problem([IOExample(Dict(:_arg_1 => 11), 22)]), 3),
	]
	problems_to_solutions = Dict(p => [label] for (p, label) in examples)

	@testset "1 predicate: reports failure, not a wrong program" begin
		final_program = conquer(
			problems_to_solutions, solutions, grammar, 1,
			sym_bool, sym_start, sym_constraint, interp,
		)
		@test isnothing(final_program)
	end

	@testset "enough predicates: separates the groups correctly" begin
		final_program = conquer(
			problems_to_solutions, solutions, grammar, 100,
			sym_bool, sym_start, sym_constraint, interp,
		)
		@test !isnothing(final_program)
		for (problem, _) in examples
			ex = only(problem.spec)
			@test interp(final_program, ex.in) == ex.out
		end
	end
end
