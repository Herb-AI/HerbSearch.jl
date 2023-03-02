"""
Searches the grammar up to the provided depth for a program that satisfies problem
"""
function enumerative_search(g::Grammars.ContextFreeGrammar, problem::Data.Problem, depth::Int, enumerator=ContextFreeEnumerator) :: Expr
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

"""
function to run metropolis search algorithm. The main difference between this function and the enumerative search is that
it passes the examples to the enumerator.
"""
function metropolis_search(g::Grammars.ContextFreeGrammar, problem::Data.Problem, depth::Int, enumerator=MetropolisHastingsEnumerator) :: Expr
    symboltable :: SymbolTable = Grammars.SymbolTable(g)

    hypotheses = enumerator(g, depth, :Real, problem.examples)

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