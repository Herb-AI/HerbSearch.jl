"""
    @enum SynthResult optimal_program=1 suboptimal_program=2

Representation of the possible results of the synth procedure. 
At the moment there are two possible outcomes:

- `optimal_program`: The synthesized program satisfies the entire program specification.
- `suboptimal_program`: The synthesized program does not satisfy the entire program specification, but got the best score from the evaluator.
"""
@enum SynthResult optimal_program=1 suboptimal_program=2

"""
    synth(problem::Problem, iterator::ProgramIterator, evaluator::Function=test_with_input, allow_evaluation_errors::Bool=false)::Union{Tuple{RuleNode, Any}, Nothing}

Synthesize a program that satisfies the maximum number of examples in the problem.
    
        - problem           - The problem definition with IO examples
        - iterator          - The iterator that will be used
        - interpreter       - The interpreter function. Takes a SymbolTable, expression and a dictionary with 
                              input variable assignments and returns the output of the expression.
        - allow_evaluation_errors - Whether the search should crash if an exception is thrown in the evaluation
Returns a tuple of the rulenode representing the solution program and a synthresult that indicates if that program is optimal
"""
function synth(
    problem::Problem,
    iterator::ProgramIterator
)::Union{Tuple{RuleNode, SynthResult}, Nothing}

    start_time = time()
    symboltable :: SymbolTable = SymbolTable(g)

    best_score = 0
    best_program = nothing
    
    for (i, candidate_program) ∈ enumerate(iterator)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(candidate_program, g)

        # Evaluate the expression
        score = evaluate(problem, expr, symboltable)
        if score == 1
            return (candidate_program, optimal_program)
        elseif score >= best_score
            best_score = score
            best_program = candidate_program
        end

        # Check stopping criteria
        if i > iterator.max_enumerations || time() - start_time > iterator.max_time
            break;
        end
    end

    # The enumeration exhausted, but an optimal problem was not found
    return (best_program, suboptimal_program)
end

# """
#     search_rulenode(problem::Problem, iterator::ProgramIterator, evaluator::Function=test_with_input, allow_evaluation_errors::Bool=false)::Union{Tuple{RuleNode, Any}, Nothing}

# Searches the grammar for the program that satisfies the maximum number of examples in the problem.
    
#         - problem           - The problem definition with IO examples
#         - iterator          - The iterator that will be used
#         - evaluator         - The evaluation function. Takes a SymbolTable, expression and a dictionary with 
#                               input variable assignments and returns the output of the expression.
#         - allow_evaluation_errors - Whether the search should crash if an exception is thrown in the evaluation
#     Returns a tuple of the rulenode and the expression of the solution program once it has been found, 
#     or nothing otherwise.
# """
# function search_rulenode(
#     problem::Problem,
#     iterator::ProgramIterator; 
#     evaluator::Function=test_with_input, 
#     allow_evaluation_errors::Bool=false
# )::Union{Tuple{RuleNode, Any}, Nothing}

#     g = iterator.grammar
#     start_time = time()
#     symboltable :: SymbolTable = SymbolTable(g)

#     for (i, h) ∈ enumerate(iterator)
#         # Create expression from rulenode representation of AST
#         expr = rulenode2expr(h, g)

#         # Evaluate the examples. 
# #         # `all` shortcircuits, so not every example will be evaluated in every iteration. 
# #         if all(example.out == evaluator(symboltable, expr, example.in) for example ∈ problem.examples)
# #             return (h, expr)
#         falsified = false
#         for example ∈ problem.examples
#             # Evaluate the example, making sure that any exceptions are caught
#             try
#                 output = evaluator(symboltable, expr, example.in)
#                 if output ≠ example.out
#                     falsified = true
#                     break
#                 end
#             catch e
#                 # Throw the error again if evaluation errors aren't allowed
#                 eval_error = EvaluationError(expr, example.in, e)
#                 allow_evaluation_errors || throw(eval_error)
#                 falsified = true
#                 break
#             end
#         end
#         if !falsified
#             return (h, expr)
#         end

#         # Check stopping conditions
#         if i > iterator.max_enumerations || time() - start_time > iterator.max_time
#             return nothing
#         end
#     end
#     return nothing
# end
