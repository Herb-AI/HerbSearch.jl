"""
Searches the grammar for the program that satisfies the maximum number of examples in the problem.
    
        - g                 - The grammar that defines the search space
        - problem           - The problem definition with IO examples
        - start             - The start symbol in the grammar
        - evaluator         - The evaluation function. Takes a SymbolTable, expression and a dictionary with 
                              input variable assignments and returns the output of the expression.
        - enumerator        - A constructor for the enumerator that should be used in the search
        - max_depth         - The maximum depth of the search
        - max_time          - The maximum time allowed for the search in seconds
        - max_enumerations  - The maximum number of programs to enumerate and test
    Returns the optimal program once it has been found, or nothing otherwise.
"""
function search(
        g::Grammar, 
        problem::Problem, 
        start::Symbol; 
        evaluator::Function=test_with_input, 
        enumerator::Function=get_bfs_enumerator,
        max_depth::Union{Int, Nothing}=nothing,
        max_time::Union{Int, Nothing}=nothing,
        max_enumerations::Union{Int, Nothing}=nothing
    )::Any

    start_time = time()
    check_time = max_time !== nothing
    check_enumerations = max_enumerations !== nothing
    symboltable :: SymbolTable = SymbolTable(g)

    hypotheses = enumerator(g, max_depth ≡ nothing ? typemax(Int) : max_depth , start)

    for (i, h) ∈ enumerate(hypotheses)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(h, g)

        # Evaluate the examples. 
        # `all` shortcircuits, so not every example will be evaluated in every iteration. 
        if all(example.out == evaluator(symboltable, expr, example.in) for example ∈ problem.examples)
            return expr
        end

        # Check stopping conditions
        if check_enumerations && i > max_enumerations || check_time && time() - start_time > max_time
            return nothing
        end
    end
    return nothing
end


"""
Default error function for `search_best`.
    
    - old_error         - The existing total error
    - output            - The actual output of the evaluator
    - expected_output   - The expected output for the example

The default function returns `0` if the outputs match and `1` otherwise.
"""
default_error_function(old_error, output, expected_output) = old_error + (output == expected_output ? 0 : 1)


"""
Searches the grammar for the program that satisfies the maximum number of examples in the problem.
The evaluator should be a function that takes a SymbolTable, expression and a dictionary with 
    input variable assignments and returns the output of the expression.

    - g                 - The grammar that defines the search space
    - problem           - The problem definition with IO examples
    - start             - The start symbol in the grammar
    - evaluator         - The evaluation function. Takes a SymbolTable, expression and a dictionary with 
                          input variable assignments and returns the output of the expression.
    - enumerator        - A constructor for the enumerator that should be used in the search
    - error_function    - The error function. Takes the existing total error, the actual output of the evaluator 
                          and the expected value for the example.
    - max_depth         - The maximum depth of the search
    - max_time          - The maximum time allowed for the search in seconds
    - max_enumerations  - The maximum number of programs to enumerate and test
Returns a tuple with the best found program so far and the error. 
Can be considerably slower than `search` due to having to evaluate each expression on each example.
"""
function search_best(
        g::Grammar, 
        problem::Problem, 
        start::Symbol;
        evaluator::Function=test_with_input, 
        enumerator::Function=get_bfs_enumerator,
        error_function::Function=default_error_function,
        max_depth::Union{Int, Nothing}=nothing,
        max_time::Union{Int, Nothing}=nothing,
        max_enumerations::Union{Int, Nothing}=nothing
    )::Tuple{Any, Real}

    start_time = time()
    check_time = max_time !== nothing
    check_enumerations = max_enumerations !== nothing
    symboltable :: SymbolTable = SymbolTable(g)

    hypotheses = enumerator(g, max_depth ≡ nothing ? typemax(Int) : max_depth , start)

    best_error = typemax(Real)
    best_program = nothing
    for (i, h) ∈ enumerate(hypotheses)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(h, g)

        # Evaluate the expression on the examples
        total_error = 0
        for example ∈ problem.examples
            total_error = error_function(total_error, evaluator(symboltable, expr, example.in), example.out)

            # Check if we can still improve the best program found so far
            if sum_of_error ≥ best_error
                break
            end
        end

        if total_error == 0
            return expr, 0
        elseif total_error < best_error
            # Update the best found example so far
            best_error = total_error
            best_program = expr
        end

        # Check stopping conditions
        if check_enumerations && i > max_enumerations || check_time && time() - start_time > max_time
            return best_program, best_error
        end
    end
    return best_program, best_error
end
