"""
	$(TYPEDSIGNATURES)

Indicates whether to keep a program as a solution to the provided (sub)problem.
Returns `True` if the program solves the given problem.
"""
function decide_if_solution(
	problem::Problem,
	program::RuleNode,
	expr::Any,
	symboltable::SymbolTable,
)
	# TODO: Is `Any` the correct type?
	score = evaluate(problem, expr, symboltable, allow_evaluation_errors = false)
	return score == 1
end

