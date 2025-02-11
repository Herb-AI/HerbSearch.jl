"""
	$(TYPEDSIGNATURES)

Indicates whether to keep a program as a solution to the provided subproblem.
Returns `True` if the program solves the given problem.

# Arguments
- `problem`: specification of the (sub)problem
- `expr`: Corresponding Julia expression of the program under decision
- `symboltable`: The symbol table used for evaluating expressions.
"""
function decide(
	problem::Problem,
	expr::Any,
	symboltable::SymbolTable,
)::Bool
	score = evaluate(problem, expr, symboltable, allow_evaluation_errors = false)
	return score == 1
end

