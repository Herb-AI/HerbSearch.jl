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


"""
Searches the grammar up to the provided depth for the program that satisfies the maximum number of examples in the problem.
The evaluator should be a function that takes a SymbolTable, expression and a dictionary with 
    input variable assignments and returns the output of the expression.
Returns a tuple with the found program and a number between 0 and 1 indicating the fraction of examples it satisfies. 
"""
function search_best(g::Grammar, problem::Problem, depth::Int, start::Symbol, evaluator=test_with_input, enumerator=get_bfs_enumerator)::Tuple{Any, Real}
    symboltable :: SymbolTable = SymbolTable(g)

    hypotheses = enumerator(g, depth, start)

    best_num_passing_examples = -1
    best_program = nothing
    for h :: RuleNode ∈ hypotheses
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(h, g)

        passing_examples = count(evaluator(symboltable, expr, example.in) == example.out for example ∈ problem.examples)
        if passing_examples == length(problem.examples)
            return expr
        elseif passing_examples > best_num_passing_examples
            best_num_passing_examples = passing_examples
            best_program = expr
        end
    end
    return best_program, best_num_passing_examples / length(problem.examples)
end
