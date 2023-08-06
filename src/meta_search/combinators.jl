abstract type Sequence
end
abstract type Parallel
end

# run for an simple algorithm
function generic_run(enumerator::Function, stopping_condition::Function, max_depth::Int, problem::Problem, grammar::ContextSensitiveGrammar;  start_program::Union{Nothing,RuleNode} = nothing)
    if isnothing(start_program)
        start_program = rand(RuleNode, grammar, 2)
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

# run for sequence 
function generic_run(::Type{Sequence}, meta_search_list::Vector, grammar::ContextSensitiveGrammar; start_program::Union{Nothing,RuleNode} = nothing)
    # first flatten the list
    # create an inital random program as the start
    if isnothing(start_program)
        start_program = rand(RuleNode, grammar, 2)
    end
    best_expression, best_program, program_cost = nothing, start_program, Inf64
    for x ∈ meta_search_list
        expression, start_program, cost = generic_run(x..., start_program = start_program)
        if cost < program_cost
            best_expression, best_program, program_cost = expression, start_program, cost
        end
    end
    println("Done with cost: $program_cost")
    return best_expression, best_program, program_cost
end

# parallel
function generic_run(::Type{Parallel}, meta_search_list::Vector, grammar::ContextSensitiveGrammar; start_program::Union{Nothing,RuleNode} = nothing)
    # create an inital random program as the start
    if isnothing(start_program)
        start_program = rand(RuleNode, grammar, 2)
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
