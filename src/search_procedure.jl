"""
Searches the grammar up to the provided depth for a program that satisfies problem
"""
function search(g::Grammar, problem::Problem, depth::Int, start::Symbol, enumerator=ExpressionIterator)::Any
    symboltable :: SymbolTable = SymbolTable(g)

    hypotheses = enumerator(g, depth, start)

    for h :: RuleNode ∈ hypotheses
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(h, g)

        # Evaluate examples the examples.
        #  `test_examples` returns as soon as it has found the first example that doesn't work.
        if test_examples(symboltable, expr, problem.examples)
            return expr
        end
    end
    return nothing
end
