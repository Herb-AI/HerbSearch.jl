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
        - problem                 - The problem definition with IO examples
        - iterator                - The iterator that will be used
        - shortcircuit            - Whether to stop evaluating after finding a single example that fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
        - allow_evaluation_errors - Whether the search should crash if an exception is thrown in the evaluation
Returns a score in the interval [0, 1]
Returns a tuple of the rulenode representing the solution program and a synthresult that indicates if that program is optimal
"""
function synth(
    problem::Problem,
    iterator::ProgramIterator; 
    shortcircuit::Bool=true, 
    allow_evaluation_errors::Bool=false
)::Union{Tuple{RuleNode, SynthResult}, Nothing}

    start_time = time()
    symboltable :: SymbolTable = SymbolTable(iterator.grammar)

    best_score = 0
    best_program = nothing
    
    for (i, candidate_program) ∈ enumerate(iterator)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(candidate_program, iterator.grammar)

        # Evaluate the expression
        score = evaluate(problem, expr, symboltable, shortcircuit=shortcircuit, allow_evaluation_errors=allow_evaluation_errors)
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
