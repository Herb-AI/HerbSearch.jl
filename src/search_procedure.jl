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



function supervised_search(
    vanilla_iterator;
    start_program::Union{AbstractRuleNode,Nothing},
    stop_channel::Union{Nothing,Channel{Bool}}=nothing,
    max_running_time = 0,
    ) 

    iterator = vanilla_iterator.iterator
    problem  = vanilla_iterator.problem
    start_time = time()
    g = get_grammar(iterator.solver)
    symboltable :: SymbolTable = SymbolTable(g)

    if !isnothing(start_program)
        set_start_program!(iterator, start_program)
    end

    best_error = typemax(Int)
    best_rulenode::Union{AbstractRuleNode, Nothing} = nothing
    for (i, h) ∈ enumerate(iterator)
        @assert !contains_hole(h) "$h has a hole inside!"
        # check to stop or not
        if !isnothing(stop_channel) && !isempty(stop_channel)
            return best_rulenode, best_error
        end

        # Create expression from rulenode representation of AST
        expr = rulenode2expr(h, g)
        
        # Evaluate the expression on the examples
        # TODO: Find a better way that does not involve hardcoding the output vector type. 
        # If I do not hardcode I get Vector{Tuple{Any, Int}} the multiple dispatch fails when called with mean_squared_error
        outputs::Vector{Tuple{<:Number,<:Number}} = [ (example.out, execute_on_input(symboltable, expr, example.in)) for example ∈ problem.spec ]
        total_error = mean_squared_error(outputs)

        if total_error == 0
            # if we have a stop channel to stop other threads signal that all threads should stop 
            if !isnothing(stop_channel) 
                safe_put!(stop_channel,true)
                close(stop_channel)
            end
            return h, total_error
        elseif total_error < best_error
            # Update the best found example so far
            best_error = total_error
            best_rulenode = deepcopy(h) # the best rulenode needs to be deepcopied because some iterators modify the output in place
            @assert !contains_hole(best_rulenode) "$best_rulenode has a hole inside!"
        end

        # Check stopping conditions
        current_time = time() - start_time
        if vanilla_iterator.stopping_condition(current_time, i, total_error) || (max_running_time > 0 && current_time > max_running_time)
            if !isnothing(best_rulenode)
                @assert !contains_hole(best_rulenode) "$best_rulenode has a hole inside!"
            end
            return best_rulenode, best_error
        end
    end
    if !isnothing(best_rulenode)
        @assert !contains_hole(best_rulenode) "$best_rulenode has a hole inside!"
    end
    return best_rulenode, best_error
end


function meta_search(
    iterator::ProgramIterator,
    grammar::AbstractGrammar;
    max_time = typemax(Int),
    max_iterations = typemax(Int),
)

    start_time = time()
    next = iterate(iterator)


    best_fitness = typemin(Int)
    iteration    = 0
    best_program = nothing
    println("Starting meta search!! ")
    prev_it_time = time()

    while !isnothing(next)
        rulenode, state = next 
        fitness = state.best_fitness
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(rulenode, grammar)
        if fitness > best_fitness
            best_fitness = fitness 
            best_program = expr
        end
        # GC.gc()

        timer = time() - prev_it_time
        println("""
        Meta Search status
            - genetic iteration   : $iteration
            - current fitness     : $fitness
            - Best fitness        : $best_fitness
            - time of iteration   : $timer
        """)

        println(repeat("_",100))
        println("Best expr: ",best_program)
        println(repeat("_",100))
        flush(stdout)

        prev_it_time = time()
        # Evaluate the expression on the examples
        current_time = time() - start_time
        if current_time > max_time || iteration > max_iterations 
            return best_program, best_fitness
        end
        next = iterate(iterator, state)
        iteration += 1
    end
    return best_program, best_fitness
end
