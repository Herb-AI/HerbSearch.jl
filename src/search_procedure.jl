using ConflictAnalysis

"""
    @enum SynthResult optimal_program=1 suboptimal_program=2

Representation of the possible results of the synth procedure. 
At the moment there are two possible outcomes:

- `optimal_program`: The synthesized program satisfies the entire program specification.
- `suboptimal_program`: The synthesized program does not satisfy the entire program specification, but got the best score from the evaluator.
"""
@enum SynthResult optimal_program=1 suboptimal_program=2

"""
    synth(problem::Problem, iterator::ProgramIterator; shortcircuit::Bool=true, allow_evaluation_errors::Bool=false, mod::Module=Main)::Union{Tuple{RuleNode, SynthResult}, Nothing}

Synthesize a program that satisfies the maximum number of examples in the problem.
        - problem                 - The problem definition with IO examples
        - iterator                - The iterator that will be used
        - shortcircuit            - Whether to stop evaluating after finding a single example that fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
        - allow_evaluation_errors - Whether the search should crash if an exception is thrown in the evaluation
        - max_time                - Maximum time that the iterator will run 
        - max_enumerations        - Maximum number of iterations that the iterator will run 
        - mod                     - A module containing definitions for the functions in the grammar that do not exist in Main

Returns a tuple of the rulenode representing the solution program and a synthresult that indicates if that program is optimal. `synth` uses `evaluate` which returns a score in the interval [0, 1] and checks whether that score reaches 1. If not it will return the best program so far, with the proper flag
"""
function synth(
    problem::Problem,
    iterator::ProgramIterator; 
    shortcircuit::Bool=true, 
    allow_evaluation_errors::Bool=false,
    max_time = typemax(Int),
    max_enumerations = typemax(Int),
    mod::Module=Main,
    conflict_analysis::Bool=true
    
)::Union{Tuple{RuleNode, SynthResult}, Nothing}
    start_time = time()
    solver = iterator.solver
    grammar = get_grammar(solver)
    symboltable :: SymbolTable = grammar2symboltable(grammar, mod)
    counter = 0

    best_score = 0
    best_program = nothing
    result = suboptimal_program

    muc_tech = MUCTechnique()

    for (i, candidate_program) ∈ enumerate(iterator)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(candidate_program, grammar)

        # Evaluate the expression
        score = evaluate(problem, expr, symboltable, shortcircuit=shortcircuit, allow_evaluation_errors=allow_evaluation_errors)
        counter = i
        if score == 1
            candidate_program = freeze_state(candidate_program)
            best_program = candidate_program
            result = optimal_program
            break;
        else
            if score >= best_score
                best_score = score
                candidate_program = freeze_state(candidate_program)
                best_program = candidate_program
            end

            # Only apply conflict analysis if shortcircuit is true
            if conflict_analysis
                faulty_spec = problem.spec[floor(Int16, score * length(problem.spec) + 1)]

                jobs = [
                    ConflictJob(muc_tech, MUCInput(candidate_program, grammar, problem, faulty_spec))
                ]
                constraints = run_conflict_pipeline(jobs)

                herb_cons = AbstractGrammarConstraint[]
                for c ∈ constraints
                    push!(herb_cons, c.cons)
                end

                if length(herb_cons) > 0
                    add_constraints!(iterator, herb_cons)
                end
            end
        end

        # Check stopping criteria
        if i > max_enumerations || time() - start_time > max_time
            println("Stopping criteria met")
            break;
        end
    end

    # Clean up
    close_solver(muc_tech)

    println("Total number of enumerations: $counter")

    # The enumeration exhausted, but an optimal problem was not found
    return (best_program, result)
end
