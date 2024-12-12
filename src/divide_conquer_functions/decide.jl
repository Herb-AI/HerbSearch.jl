"""
	$(TYPEDSIGNATURES)

Indicates whether to keep a program as a solution to the provided subproblem.
Returns `True` if the program solves the given problem.
"""
function decide_if_solution(
	problem::Problem,
	expr::Any,
	symboltable::SymbolTable,
)
	score = evaluate(problem, expr, symboltable, allow_evaluation_errors = false)
	return score == 1
end

