using HerbBenchmarks.PBE_BV_Track_2018

# Slightly modified grammar
grammar = @cfgrammar begin # modified PBE_BV_Track_2018.grammar_PRE_100_10
	Start = 0x0000000000000000
	Start = 0x0000000000000001
	Input = _arg_1 # :Input added
	Start = Input
	# Start = _arg_1	
	Start = bvnot_cvc(Start)
	Start = smol_cvc(Start)
	Start = ehad_cvc(Start)
	Start = arba_cvc(Start)
	Start = shesh_cvc(Start)
	Start = bvand_cvc(Start, Start)
	Start = bvor_cvc(Start, Start)
	Start = bvxor_cvc(Start, Start)
	Start = bvadd_cvc(Start, Start)
	Start = im_cvc(Start, Start, Start)
end
problem = PBE_BV_Track_2018.problem_PRE_100_10

@testset verbose = true "Benchmark BV example for divide and conquer" begin
	# search parameters
	max_enumerations = 2
	iterator = BFSIterator(grammar, :Start)
	problems_to_solutions = divide_and_conquer(
		problem,
		iterator,
		divide_by_example,
		decide_if_solution,
		max_enumerations,
	)

	# Combine solutions to one final program
	# --------------------------
	# return_type = grammar.rules[grammar.bytype[sym_start][1]]    

	# idx = findfirst(r -> r == :($sym_bool ? $return_type : $return_type), grammar.rules)
	# # add condition rule for easy access when outputing
	# if isnothing(idx)
	# 	add_rule!(grammar, :($sym_start = $sym_bool ? $return_type : $return_type))
	# 	idx = length(grammar.rules)
	# end
	# --------------------------
	n_predicates = 5
	sym_bool = :Start
	sym_start = :Start
	sym_constraint = :Input

	symboltable::SymbolTable = SymbolTable(grammar)
	# test error is thrown when no if-else rule in grammar
	@test_throws HerbSearch.ConditionalIfElseError HerbSearch.conquer_combine(
		problems_to_solutions,
		grammar,
		n_predicates,
		sym_bool,
		sym_start,
		sym_constraint,
		symboltable,
	)
	# add if-else rule to grammar
	add_rule!(grammar, :($sym_start = $sym_bool ? $sym_start : $sym_start))
	symboltable = SymbolTable(grammar)
	result = HerbSearch.conquer_combine(
		problems_to_solutions,
		grammar,
		n_predicates,
		sym_bool,
		sym_start,
		sym_constraint,
		symboltable,
	)
	println("Final result: ", result) # should be index of if-else statement
end
