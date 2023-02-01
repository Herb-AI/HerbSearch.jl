"""
Searches the grammar up to the provided depth for a program that satisfies problem
"""
function enumerative_search(g::Grammars.ContextFreeGrammar, problem::Data.Problem, depth::Int, enumerator=ContextFreeEnumerator) :: Expr
    symboltable :: SymbolTable = Grammars.SymbolTable(g)

    hypotheses = enumerator(g, depth, :Real)

    for h :: RuleNode ∈ hypotheses
        # Create expression from rulenode representation of AST
        expr = Grammars.rulenode2expr(h, g)
        falsified = false
        for ex :: IOExample ∈ problem.examples
            # Add input variable values to the symbol table
            symbols = merge(symboltable, ex.in)
            # Calculate result
            output = Evaluation.interpret(symbols, expr)
            # Check if output matches example
            if output != ex.out
                falsified = true
                break
            end
        end
        if !falsified
            return expr
        end
    end
end