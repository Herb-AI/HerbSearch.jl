"""
    @enum SynthResult optimal_program=1 suboptimal_program=2

Representation of the possible results of the synth procedure. 
At the moment there are two possible outcomes:

- `optimal_program`: The synthesized program satisfies the entire program specification.
- `suboptimal_program`: The synthesized program does not satisfy the entire program specification, but got the best score from the evaluator.
"""
@enum SynthResult optimal_program=1 suboptimal_program=2

get_rulenode_from_iterator(::ProgramIterator, x::AbstractRuleNode) = x

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
    mod::Module=Main
    
)::Union{Tuple{RuleNode, SynthResult}, Nothing}
    start_time = time()
    grammar = get_grammar(iterator.solver)
    symboltable :: SymbolTable = SymbolTable(grammar, mod)

    best_score = 0
    best_program = nothing
    
    for (i, itearator_value) ∈ enumerate(iterator)
        candidate_program = get_rulenode_from_iterator(iterator, itearator_value)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(candidate_program, grammar)

        # Evaluate the expression
        score = evaluate(problem, expr, symboltable, shortcircuit=shortcircuit, allow_evaluation_errors=allow_evaluation_errors)
        if score == 1
            candidate_program = freeze_state(candidate_program)
            return (candidate_program, optimal_program)
        elseif score >= best_score
            best_score = score
            candidate_program = freeze_state(candidate_program)
            best_program = candidate_program
        end

        # Check stopping criteria
        if i > max_enumerations || time() - start_time > max_time
            break;
        end
    end

    # The enumeration exhausted, but an optimal problem was not found
    return (best_program, suboptimal_program)
end


mse_error_function_strings(output::Char, expected_output::String) = mse_error_function_strings(string(output), expected_output)
mse_error_function_strings(output::String, expected_output::Char) = mse_error_function_strings(output, string(expected_output))
mse_error_function_strings(output::Char, expected_output::Char) = mse_error_function_strings(string(output), string(expected_output))

function mse_error_function_strings(output::String, expected_output::String)
    return edit_distance(output,expected_output)
end

function supervised_search(
    problem::Problem,
    iterator::ProgramIterator, 
    stopping_condition::Function,
    start_program::RuleNode;
    error_function::Function=default_error_function,
    stop_channel::Union{Nothing,Channel{Bool}}=nothing,
    max_time = 0,
    )::Tuple{RuleNode, Real}

    start_time = time()
    g = get_grammar(iterator.solver)
    symboltable :: SymbolTable = SymbolTable(g)

    enumerator = Base.Iterators.rest(iterator, construct_state_from_start_program(typeof(iterator),start_program=start_program))

    best_error = typemax(Int)
    best_rulenode = nothing
    for (i, h) ∈ enumerate(enumerator)
        # check to stop or not
        if !isnothing(stop_channel) && !isempty(stop_channel)
            return best_rulenode, best_error
        end

        # Create expression from rulenode representation of AST
        expr = rulenode2expr(h, g)
        
        # Evaluate the expression on the examples
        total_error = 0
        for example ∈ problem.examples
            example_outcome = execute_on_input(symboltable, expr, example.in)
            total_error += error_function(example_outcome, example.out)
        end

        if total_error == 0
            if !isnothing(stop_channel) 
                safe_put!(stop_channel,true)
                close(stop_channel)
            end
            return h, total_error
        elseif total_error < best_error
            # Update the best found example so far
            best_error = total_error
            best_rulenode = h
        end

        # Check stopping conditions
        current_time = time() - start_time
        if stopping_condition(current_time, i, total_error) || (max_time > 0 && current_time > max_time)
            return best_rulenode, best_error
        end
    end
    return best_rulenode, best_error
end


function meta_search(
    g::ContextSensitiveGrammar, 
    start::Symbol;
    stopping_condition::Function,
    enumerator::Function,
    )::Tuple{Any, Real}

    start_time = time()

    # genetic search ignores max_depth and max_size
    hypotheses = enumerator(
        g, 
        typemax(Int), 
        typemax(Int),
        start
    )

    best_fitness = 0
    best_program = nothing
    println("Starting meta search!! ")
    prev_time = time()
    for (i, iteartor_value) ∈ enumerate(hypotheses)
        rulenode = get_rulenode_from_iterator(iter, itearator_value)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(rulenode, g)
        if fitness > best_fitness
            best_fitness = fitness 
            best_program = expr
        end
        # GC.gc()

        timer = time() - prev_time
        println("""
        Meta Search status
            - genetic iteration   : $i 
            - current fitness     : $fitness
            - Best fitness        : $best_fitness
            - time of iteration   : $timer
            - estimate of runtime : $(estimate_runtime_of_one_genetic_iteration())
        """)

        println(repeat("_",100))
        println("Best expr: ",best_program)
        println(repeat("_",100))
        flush(stdout)

        prev_time = time()
        # Evaluate the expression on the examples
        current_time = time() - start_time
        if stopping_condition(current_time, i, fitness)
            return best_program, best_fitness
        end
    end
    return best_program, best_fitness
end
