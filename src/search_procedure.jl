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
        evaluator=test_with_input, 
        enumerator=get_bfs_enumerator,
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
Searches the grammar for the program that satisfies the maximum number of examples in the problem.
The evaluator should be a function that takes a SymbolTable, expression and a dictionary with 
    input variable assignments and returns the output of the expression.

    - g                 - The grammar that defines the search space
    - problem           - The problem definition with IO examples
    - start             - The start symbol in the grammar
    - evaluator         - The evaluation function. Takes a SymbolTable, expression and a dictionary with 
                          input variable assignments and returns the output of the expression.
    - enumerator        - A constructor for the enumerator that should be used in the search
    - max_depth         - The maximum depth of the search
    - max_time          - The maximum time allowed for the search in seconds
    - max_enumerations  - The maximum number of programs to enumerate and test
Returns a tuple with the best found program so far and a number between 0 and 1 indicating the fraction of examples it satisfies. 
Can be considerably slower than `search` due to having to evaluate each expression on each example.
"""
function search_best(
        g::Grammar, 
        problem::Problem, 
        start::Symbol;
        evaluator=test_with_input, 
        enumerator=get_bfs_enumerator,
        max_depth::Union{Int, Nothing}=nothing,
        max_time::Union{Int, Nothing}=nothing,
        max_enumerations::Union{Int, Nothing}=nothing
    )::Tuple{Any, Real}

    start_time = time()
    check_time = max_time !== nothing
    check_enumerations = max_enumerations !== nothing
    symboltable :: SymbolTable = SymbolTable(g)

    hypotheses = enumerator(g, max_depth ≡ nothing ? typemax(Int) : max_depth , start)

    best_num_passing_examples = -1
    best_program = nothing
    for (i, h) ∈ enumerate(hypotheses)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(h, g)

        # Evaluate the expression on the examples
        passing_examples = 0
        for (j, example) ∈ enumerate(problem.examples)
            passing_examples += evaluator(symboltable, expr, example.in) == example.out ? 1 : 0

            # Check if we can still improve the best program found so far
            if passing_examples + length(problem.examples) - j ≤ best_num_passing_examples
                break
            end
        end

        if passing_examples == length(problem.examples)
            return expr, 1
        elseif passing_examples > best_num_passing_examples
            # Update the best found example so far
            best_num_passing_examples = passing_examples
            best_program = expr
        end

        # Check stopping conditions
        if check_enumerations && i > max_enumerations || check_time && time() - start_time > max_time
            return best_program, best_num_passing_examples / length(problem.examples)
        end
    end
    return best_program, best_num_passing_examples / length(problem.examples)
end
