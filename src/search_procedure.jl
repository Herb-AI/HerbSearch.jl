"""
Searches the grammar up to the provided depth for a program that satisfies problem.
The evaluator should be a function that takes a SymbolTable, expression and a dictionary with 
    input variable assignments and returns the output of the expression.
"""
function search(g::Grammar, problem::Problem, depth::Int, start::Symbol, evaluator=test_with_input, enumerator=get_bfs_enumerator)::Any
    symboltable :: SymbolTable = SymbolTable(g)

    hypotheses = enumerator(g, depth, start)

    for h :: RuleNode ∈ hypotheses
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(h, g)

        # Evaluate the examples.
        satisfied = true
        for example ∈ filter(e -> e isa IOExample, problem.examples)
            if example.out ≠ evaluator(symboltable, expr, example.in)
                satisfied = false
                break
            end
        end
        if satisfied
            return expr
        end
    end
    return nothing
end