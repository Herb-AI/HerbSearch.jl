abstract type Sequence
end
abstract type Parallel
end

"""
    generic_run(enumerator::Function, stopping_condition::Function, max_depth::Int, problem::Problem, grammar::ContextSensitiveGrammar;  start_program::Union{Nothing,RuleNode} = nothing)

Runs an simple vanilla search algorithm represented by an enumerator until the stopping condition is met. 
It uses [`HerbSearch.supervised_search`](@ref) to run the enumerator and monitor the stopping condition.

Returns a tuple consisting of the `(expression found, program as rulenode, program cost)`
"""
function generic_run(enumerator::Function, stopping_condition::Function, max_depth::Int, problem::Problem, grammar::ContextSensitiveGrammar;  start_program::Union{Nothing,RuleNode} = nothing)
    if isnothing(start_program)
        start_program = rand(RuleNode, grammar, max_depth)
    end
    program, rulenode, cost = HerbSearch.supervised_search(
        grammar,
        problem,
        :X, # TODO: remove hardcoding of variable X
        stopping_condition, 
        start_program,
        max_depth = max_depth, 
        enumerator = enumerator,
        error_function = HerbSearch.mse_error_function
    )
    return program, rulenode, cost
end

"""
    generic_run(::Type{Sequence}, meta_search_list::Vector, max_depth::Int, grammar::ContextSensitiveGrammar; start_program::Union{Nothing,RuleNode} = nothing)

Runs an sequence of combinators represented by `meta_search_list`. 
Sequence(A,B,C) means that:
1. A is ran first and the outcome program of A is given to B.
2. B is ran second and the outcome program of B is given to C
3. C is ran third and the outcome program of C is the end outcome of the sequence step.
Note that `A`,`B`,`C` can be vanila algorithms or other combinators (sequence or parallel) 

## Notes
If the `start_program` of `A` is not given (e.g `nothing`) a random program is sampled from the grammar with the given `max_depth`.
The sequence step is stopped once an algorithm achieves cost `0`, meaning it satisfies all input/output examples.

Returns a tuple consisting of the `(expression found, program as rulenode, program cost)` coresponding to the best program found (lowest cost).
"""
function generic_run(::Type{Sequence}, meta_search_list::Vector, max_depth::Int, grammar::ContextSensitiveGrammar; start_program::Union{Nothing,RuleNode} = nothing)
    # first flatten the list
    # create an inital random program as the start
    if isnothing(start_program)
        start_program = rand(RuleNode, grammar, max_depth)
    end
    best_expression, best_program, program_cost = nothing, start_program, Inf64
    for x ∈ meta_search_list
        expression, start_program, cost = generic_run(x..., start_program = start_program)
        if cost < program_cost
            best_expression, best_program, program_cost = expression, start_program, cost
        end
        # if we reached cost 0 then we have a working program, there is no point in continuing the sequence
        if cost == 0
            break
        end
    end
    println("Done with cost: $program_cost")
    return best_expression, best_program, program_cost
end


"""
    generic_run(::Type{Parallel}, meta_search_list::Vector, max_depth::Int, grammar::ContextSensitiveGrammar; start_program::Union{Nothing,RuleNode} = nothing)

Runs combinators in parallel from the `meta_search_list`. 
Parallel(A,B,C) means that A,B,C are ran in parallel on different threads.

## Notes
If the `start_program` of `A` is not given (e.g `nothing`) a random program is sampled from the grammar with the given `max_depth`.
The sequence step is stopped once an algorithm achieves cost `0`, meaning it satisfies all input/output examples.

Returns a tuple consisting of the `(expression found, program as rulenode, program cost)` coresponding to the best program found (lowest cost).
"""
function generic_run(::Type{Parallel}, meta_search_list::Vector, max_depth::Int, grammar::ContextSensitiveGrammar; start_program::Union{Nothing,RuleNode} = nothing)
    # create an inital random program as the start
    if isnothing(start_program)
        start_program = rand(RuleNode, grammar, max_depth)
    end
    best_expression, best_program, program_cost = nothing, start_program, Inf64
    # use threads
    Threads.@threads for meta ∈ meta_search_list
        expression, outcome_program, cost = generic_run(meta..., start_program = start_program)
        if cost < program_cost
            best_expression, best_program, program_cost = expression, outcome_program, cost
        end
    end
    println("Done with cost: $program_cost")
    return best_expression, best_program, program_cost
end
