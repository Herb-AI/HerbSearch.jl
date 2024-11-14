"""
    decide_take_first(problem::Problem, program::RuleNode, solutions::Dict{Problem, Vector{RuleNode}}, symbol_table::SymbolTable)

Indicates whether to keep a program as a solution to the provided (sub)problem.
Returns `True` if the program solves the given problem and there is no solution to the problem yet.
"""
function decide_take_first(problem::Problem, program::RuleNode, solutions::Dict{Problem, Vector{RuleNode}}, symboltable::SymbolTable)
    # TODO: Evaluate if program solves given problem. Return true if so, false otherwise. 
    # score = evaluate(problem, expr, symboltable, shortcircuit=shortcircuit, allow_evaluation_errors=allow_evaluation_errors)
    # return score == 1
end

