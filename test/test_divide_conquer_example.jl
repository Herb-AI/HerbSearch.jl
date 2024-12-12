using HerbBenchmarks.PBE_BV_Track_2018

# Get example problem
# prob_gram_pairs = all_problem_grammar_pairs(PBE_SLIA_Track_2019)

grammar = PBE_BV_Track_2018.grammar_PRE_100_10
problem = PBE_BV_Track_2018.problem_PRE_100_10

# println(typeof(problem))
# println("Problem: ", problem.spec)
# println("Number of examples: ", length(problem.spec))
# println(typeof(problem.spec[1]))

@testset verbose = true "Benchmark BV example for divide and conquer" begin
	# search parameters
	max_enumerations = 2
	# We need an iterator.
	iterator = BFSIterator(grammar, :Start)
	problems_to_solutions, subproblems = divide_and_conquer(
		problem,
		iterator,
		divide_by_example,
		decide_if_solution,
		max_enumerations,
	)
	println(problems_to_solutions[subproblems[1]])
	# function divide_and_conquer(problem::Problem,
	#     iterator::ProgramIterator,
	#     divide::Function = divide_by_example,
	#     decide::Function = decide_if_solution,
	#     conquer::Function = conquer_combine,
	#     max_time = typemax(Int),
	#     max_enumerations = typemax(Int),
	#     mod::Module = Main,
	# )
end
