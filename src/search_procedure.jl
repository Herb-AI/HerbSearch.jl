"""
    search_rulenode(g::Grammar, problem::Problem, start::Symbol; evaluator::Function=execute_on_input, enumerator::Function=get_bfs_enumerator, max_depth::Union{Int, Nothing}=nothing, max_size::Union{Int, Nothing}=nothing, max_time::Union{Int, Nothing}=nothing, max_enumerations::Union{Int, Nothing}=nothing, allow_evaluation_errors::Bool=false)::Union{Tuple{RuleNode, Any}, Nothing}

Searches the grammar for the program that satisfies the maximum number of examples in the problem.
    
        - g                 - The grammar that defines the search space
        - problem           - The problem definition with IO examples
        - start             - The start symbol in the grammar
        - evaluator         - The evaluation function. Takes a SymbolTable, expression and a dictionary with 
                              input variable assignments and returns the output of the expression.
        - enumerator        - A constructor for the enumerator that should be used in the search
        - max_depth         - The maximum depth of the search
        - max_size          - The maximum number of nodes for ASTs in the search
        - max_time          - The maximum time allowed for the search in seconds
        - max_enumerations  - The maximum number of programs to enumerate and test'
        - allow_evaluation_errors - Whether the search should crash if an exception is thrown in the evaluation
    Returns a tuple of the rulenode and the expression of the solution program once it has been found, 
    or nothing otherwise.
"""
function search_rulenode(
    g::Grammar, 
    problem::Problem, 
    start::Symbol; 
    evaluator::Function=execute_on_input, 
    enumerator::Function=get_bfs_enumerator,
    max_depth::Union{Int, Nothing}=nothing,
    max_size::Union{Int, Nothing}=nothing,
    max_time::Union{Int, Nothing}=nothing,
    max_enumerations::Union{Int, Nothing}=nothing,
    allow_evaluation_errors::Bool=false
)::Union{Tuple{RuleNode, Any}, Nothing}

    start_time = time()
    check_time = max_time !== nothing
    check_enumerations = max_enumerations !== nothing
    symboltable :: SymbolTable = SymbolTable(g)

    hypotheses = enumerator(
        g, 
        max_depth ≡ nothing ? typemax(Int) : max_depth, 
        max_size ≡ nothing ? typemax(Int) : max_size,
        start
    )

    for (i, h) ∈ enumerate(hypotheses)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(h, g)

        # Evaluate the examples. 
#         # `all` shortcircuits, so not every example will be evaluated in every iteration. 
#         if all(example.out == evaluator(symboltable, expr, example.in) for example ∈ problem.spec)
#             return (h, expr)
        falsified = false
        for example ∈ problem.spec
            # Evaluate the example, making sure that any exceptions are caught
            try
                output = evaluator(symboltable, expr, example.in)
                if output ≠ example.out
                    falsified = true
                    break
                end
            catch e
                # Throw the error again if evaluation errors aren't allowed
                allow_evaluation_errors || throw(e)
                falsified = true
                break
            end
        end
        if !falsified
            return (h, expr)
        end

        # Check stopping conditions
        if check_enumerations && i > max_enumerations || check_time && time() - start_time > max_time
            return nothing
        end
    end
    return nothing
end


"""
    search(g::Grammar, problem::Problem, start::Symbol; evaluator::Function=execute_on_input, enumerator::Function=get_bfs_enumerator, max_depth::Union{Int, Nothing}=nothing, max_size::Union{Int, Nothing}=nothing, max_time::Union{Int, Nothing}=nothing, max_enumerations::Union{Int, Nothing}=nothing, allow_evaluation_errors::Bool=false)::Union{Any, Nothing}

Searches for a program by calling [`search_rulenode`](@ref) starting from [`Symbol`](@ref) `start` guided by `enumerator` and [`Grammar`](@ref) trying to satisfy  the higher-order constraints in form of input/output examples defined in the [`Problem`](@ref). 
This is the heart of the Herb's search for satisfying programs.
Returns the found program when the evaluation calculated using `evaluator` is successful.
"""
function search(
    g::Grammar, 
    problem::Problem, 
    start::Symbol; 
    evaluator::Function=execute_on_input, 
    enumerator::Function=get_bfs_enumerator,
    max_depth::Union{Int, Nothing}=nothing,
    max_size::Union{Int, Nothing}=nothing,
    max_time::Union{Int, Nothing}=nothing,
    max_enumerations::Union{Int, Nothing}=nothing,
    allow_evaluation_errors::Bool=false
)::Union{Any, Nothing}
    res::Union{Tuple{RuleNode, Any}, Nothing} = search_rulenode(
        g,
        problem,
        start,
        evaluator=evaluator,
        enumerator=enumerator,
        max_depth=max_depth,
        max_size=max_size,
        max_time=max_time,
        max_enumerations=max_enumerations,
        allow_evaluation_errors=allow_evaluation_errors
    )

    if res isa Tuple{RuleNode, Any}
        return res[2]
    end
    return nothing
end

"""
    default_error_function(old_error, output, expected_output)
Default error function for `search_best`.
    
    - old_error         - The existing total error
    - output            - The actual output of the evaluator
    - expected_output   - The expected output for the example

The default function returns `0` if the outputs match and `1` otherwise.
"""
default_error_function(old_error, output, expected_output) = old_error + (output == expected_output ? 0 : 1)

"""
    mse_error_function(old_error, output, expected_output)
Mean squared error function for `search_best`.
    
    - old_error         - The existing total error
    - output            - The actual output of the evaluator
    - expected_output   - The expected output for the example

The function build the mean squared error from `output` and `expected_output``.
"""
mse_error_function(old_error, output, expected_output) = old_error + (output - expected_output) ^ 2

mse_error_function_strings(output::Char, expected_output::String) = mse_error_function_strings(string(output), expected_output)
mse_error_function_strings(output::String, expected_output::Char) = mse_error_function_strings(output, string(expected_output))
mse_error_function_strings(output::Char, expected_output::Char) = mse_error_function_strings(string(output), string(expected_output))


function mse_error_function_strings(output::String, expected_output::String)
    edit_dist = edit_distance(output,expected_output)
    return edit_dist 
end

mse_error_function(old_error, output::String, expected_output::String) =  old_error + mse_error_function_strings(output, expected_output)


"""
    search_best(g::Grammar, problem::Problem, start::Symbol; evaluator::Function=execute_on_input, enumerator::Function=get_bfs_enumerator, error_function::Function=default_error_function, max_depth::Union{Int, Nothing}=nothing, max_size::Union{Int, Nothing}=nothing, max_time::Union{Int, Nothing}=nothing, max_enumerations::Union{Int, Nothing}=nothing, allow_evaluation_errors::Bool=false)::Tuple{Any, Real}

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
    - allow_evaluation_errors - Whether the search should crash if an exception is thrown in the evaluation
Returns a tuple with the best found program so far and the error. 
Can be considerably slower than `search` due to having to evaluate each expression on each example.
"""
function search_best(
        g::Grammar, 
        problem::Problem, 
        start::Symbol;
        evaluator::Function=execute_on_input, 
        enumerator::Function=get_bfs_enumerator,
        error_function::Function=default_error_function,
        get_rulenode_from_iterator::Function = program -> program,
        max_depth::Union{Int, Nothing}=nothing,
        max_size::Union{Int, Nothing}=nothing,
        max_time::Union{Int, Nothing}=nothing,
        max_enumerations::Union{Int, Nothing}=nothing,
        allow_evaluation_errors::Bool=false
    )::Tuple{Any, Real, RuleNode}

    start_time = time()
    check_time = max_time !== nothing
    check_enumerations = max_enumerations !== nothing
    symboltable :: SymbolTable = SymbolTable(g)

    hypotheses = enumerator(
        g, 
        max_depth ≡ nothing ? typemax(Int) : max_depth, 
        max_size ≡ nothing ? typemax(Int) : max_size,
        start
    )
    
    best_error = typemax(Int)
    best_program = nothing
    best_rulenode = nothing
    for (i, h) ∈ enumerate(hypotheses)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(get_rulenode_from_iterator(h), g)

        # Evaluate the expression on the examples
        total_error = 0
        crashed = false
        for example ∈ problem.spec
            try
                output = evaluator(symboltable, expr, example.in)
                total_error = error_function(total_error, output, example.out)
            catch e
                # You could also decide to handle less severe errors (such as index out of range) differently,
                # for example by just increasing the error value and keeping the program as a candidate.
                crashed = true
                # Throw the error again if evaluation errors aren't allowed
                allow_evaluation_errors || throw(e)
                total_error = Inf
                break
            end

            # Check if we can still improve the best program found so far
            if total_error ≥ best_error
                break
            end
        end

        if crashed 
            # do nothing
        elseif total_error == 0
            @info "Reached error 0"
            @info "Program: $h"
            return expr, 0, best_rulenode
        elseif total_error < best_error
            # Update the best found example so far
            best_error = total_error
            best_program = expr
            best_rulenode = h
        end
        # Check stopping conditions
        if check_enumerations && i > max_enumerations || check_time && time() - start_time > max_time
            # @warn "Stopping search because of time or enumerations"
            return best_program, best_error, best_rulenode
        end
    end
    return best_program, best_error, best_rulenode
end


function supervised_search(
    g::ContextSensitiveGrammar, 
    examples::Array{<:IOExample}, 
    start::Symbol,
    stopping_condition::Function,
    start_program::RuleNode;
    evaluator::Function=execute_on_input,
    enumerator::Function=get_bfs_enumerator,
    state=StochasticIteratorState,
    error_function::Function=default_error_function,
    max_depth::Union{Int, Nothing}=nothing,
    )::Tuple{Any, Any, Real}

    start_time = time()
    symboltable :: SymbolTable = SymbolTable(g)

    iterator = enumerator(
        g, 
        max_depth ≡ nothing ? typemax(Int) : max_depth, 
        typemax(Int),
        start
    )
    # instead of calling StochasticIteratorState(current_program = current_program) I abstracted away to a function call that creates 
    # the appropriate struct for a given iterator. (Different iterators can have different structs for the StochasticIteratorState)
    hypotheses = Base.Iterators.rest(iterator, state(current_program=start_program))

    best_error = typemax(Int)
    best_program = nothing
    best_rulenode = nothing
    # println("Starting search ",Threads.threadid(),"\n============")
    for (i, h) ∈ enumerate(hypotheses)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(h, g)
        
        # Evaluate the expression on the examples
        total_error = 0
        for example ∈ examples
            total_error = error_function(total_error, evaluator(symboltable, expr, example.in), example.out)
        end

        if total_error == 0
            return expr, h, 0
        elseif total_error < best_error
            # Update the best found example so far
            best_error = total_error
            best_program = expr
            best_rulenode = h
        end

        # Check stopping conditions
        current_time = time() - start_time
        # current_time > 5 is just for debugging to make it not run forever :)
        if stopping_condition(current_time, i, total_error)
            return best_program, best_rulenode, best_error
        end
    end
    return best_program, best_rulenode, best_error
end


function meta_search(
    g::ContextSensitiveGrammar, 
    start::Symbol;
    stopping_condition::Function,
    start_program::RuleNode,
    enumerator::Function=get_bfs_enumerator,
    state=StochasticIteratorState,
    max_depth::Union{Int, Nothing}=nothing,
    )::Tuple{Any, Real}

    start_time = time()
    iterator = enumerator(
        g, 
        max_depth ≡ nothing ? typemax(Int) : max_depth, 
        typemax(Int),
        start
    )
    hypotheses = Base.Iterators.rest(iterator, state(current_program=start_program))

    best_fitness = 0
    best_program = nothing
    println("Starting meta search!! ")
    
    for (i, (rulenode, fitness)) ∈ enumerate(hypotheses)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(rulenode, g)
        if fitness > best_fitness
            best_fitness = fitness 
            best_program = expr
        end

        println("""
        Meta Search status
            - genetic iteration   : $i 
            - current fitness     : $fitness
            - Best fitness        : $best_fitness
        """)

        println(repeat("_",100))
        println("Best expr: ",best_program)
        println(repeat("_",100))
        println("Current expr: ",expr)
        println(repeat("=",100))

        # Evaluate the expression on the examples
        current_time = time() - start_time
        if stopping_condition(current_time, i, fitness)
            return best_program, best_fitness
        end
    end
    return best_program, best_fitness
end
