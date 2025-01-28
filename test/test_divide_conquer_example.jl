using HerbBenchmarks.PBE_BV_Track_2018

# Modified grammar (for original grammar, see PBE_BV_Track_2018.grammar_PRE_100_10)
grammar = @cfgrammar begin
	Start = 0x0000000000000000
	Start = 0x0000000000000001
	Start = Input
	Input = _arg_1 # :Input added
	Start = Bool
	Bool = Condition # only introduced for constraint on predicates iterator
	Condition = bvugt_cvc(Start, Start) # n1 > n2
	Condition = bveq1_cvc(Start) # n == 1
	Start = bvnot_cvc(Start)
	Start = smol_cvc(Start)
	Start = ehad_cvc(Start)
	Start = arba_cvc(Start)
	Start = shesh_cvc(Start)
	Start = bvand_cvc(Start, Start)
	Start = bvor_cvc(Start, Start)
	Start = bvxor_cvc(Start, Start)
	Start = bvadd_cvc(Start, Start)
	Start = im_cvc(Start, Start, Start) # if-else statement
end

# additional bitoperations for modified grammar
bvugt_cvc(n1::UInt, n2::UInt) = n1 > n2 ? UInt(1) : UInt(0) # returns whether n1 > n2
bveq1_cvc(n::UInt) = n == UInt(1) ? UInt(1) : UInt(0)

# load benchmark problem
problem = PBE_BV_Track_2018.problem_PRE_100_10

@testset verbose = true "Benchmark BV example for divide and conquer" begin
	# input arguments
	n_predicates = 50
	sym_bool = :Bool
	sym_start = :Start
	sym_constraint = :Input
	max_enumerations = 10

	iterator = BFSIterator(grammar, :Start)
	idx_ifelse = findfirst(r -> r == :($sym_bool ? $sym_start : $sym_start), grammar.rules)
	@test_throws HerbSearch.ConditionalIfElseError divide_and_conquer(
		problem,
		iterator,
		sym_bool,
		sym_start,
		sym_constraint,
		n_predicates,
		max_enumerations,
	)

	# add if-else rule to grammar
	add_rule!(grammar, :($sym_start = $sym_bool ? $sym_start : $sym_start))
	iterator = BFSIterator(grammar, :Start)

	final_program = divide_and_conquer(
		problem,
		iterator,
		sym_bool,
		sym_start,
		sym_constraint,
		n_predicates,
		max_enumerations,
	)
end

