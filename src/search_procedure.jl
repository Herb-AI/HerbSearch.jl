"""
Searches the grammar up to the provided depth for a program that satisfies problem
"""
function search(g::Grammars.ContextFreeGrammar, problem::Data.Problem, depth::Int, enumerator=ContextFreeEnumerator) :: Expr
    symboltable :: SymbolTable = Grammars.SymbolTable(g)

    hypotheses = enumerator(g, depth, :Real)

    for h :: RuleNode ∈ hypotheses
        # Create expression from rulenode representation of AST
        expr = Grammars.rulenode2expr(h, g)

        # Evaluate examples the examples.
        #  `evaluate examples` returns as soon as it has found the first example that doesn't work.
        if Evaluation.evaluate_examples(symboltable, expr, problem.examples)
            return expr
        end
    end
end