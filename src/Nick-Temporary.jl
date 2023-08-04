using HerbCore 
using HerbGrammar
using HerbData
using HerbSearch
using Logging
disable_logging(LogLevel(1))

using Base.Threads


arithmetic_grammar = @csgrammar begin
    X = |(1:5)
    X = X * X
    X = X + X
    X = X - X
    X = x
end

grammar = @csgrammar begin
    # S = run(A...)
    S = generic_run(COMBINATOR...;)
    MS = A
    MS = COMBINATOR
    A = mh(),STOPFUNCTION
    # A = vlns,STOP
    A = sa(),STOPFUNCTION
    # A = ga,STOP
    # A = dfs,STOP
    # A = bfs,STOP
    # A = astar,STOP
    # MHCONFIGURATION = MAXDEPTH
    # MAXDEPTH = 3
    COMBINATOR = (Sequence,ALIST)
    COMBINATOR = (Parallel,ALIST)
    ALIST = [MS;MS]
    ALIST = [MS;ALIST]
    # COMBINATOR = sequence(MSLIST)
    # COMBINATOR = parallel([MSLIST],SELECT)
    # MSLIST = MS,MS
    # MSLIST = MS,MSLIST
    # SELECT = best | crossover | mutate
    STOPFUNCTION = (time, iteration, cost) -> STOPCONDITION
    STOPCONDITION = STOPTERM
    STOPCONDITION = STOPTERM && STOPCONDITION
    # STOPTERM = OPERAND == VALUE
    STOPTERM = ITERATION_STOP
    ITERATION_STOP = iteration > VALUE
    # STOPTERM = OPERAND < VALUE
    # OPERAND = time | iteration | cost
    OPERAND = iteration
    VALUE = |(1:10)
    VALUE = 10 * VALUE
end

# CREATE A PROBLEM
function create_problem(f, range=5)
    examples = [HerbData.IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
    return HerbData.Problem(examples), examples
end

problem, examples = create_problem(x -> x ^ 4 + x * x + 2 * x + 5)

# HELPER FUNCTIONS
function mh()
    enumerator = HerbSearch.get_mh_enumerator(examples, HerbSearch.mean_squared_error)
    return enumerator
end

function sa()
    enumerator = HerbSearch.get_sa_enumerator(examples, HerbSearch.mean_squared_error, 5)
    return enumerator
end


abstract type Sequence
end
abstract type Parallel
end

# run simple(algorithm,stopping_condition)
# sequence(::Type{Sequence}, startprogram,  [sequence(), sequence(), parallel()])
# parallel(::Type{Paralell}, start_program, [sequence(), sequence(), parallel()])

# run for an simple algorithm
function generic_run(enumerator::Function, stopping_condition::Function; start_program::RuleNode=rand(RuleNode, arithmetic_grammar, :X, 2))
    program, rulenode, cost = HerbSearch.supervised_search(arithmetic_grammar, problem, :X, stopping_condition, start_program, enumerator=enumerator, error_function=HerbSearch.mse_error_function)
    return program, rulenode, cost
end

# run for sequence 
function generic_run(::Type{Sequence}, meta_search_list::Vector; start_program::Union{Nothing,RuleNode} = nothing)
    # first flatten the list
    # create an inital random program as the start
    if isnothing(start_program)
        start_program = rand(RuleNode, arithmetic_grammar, :X, 2)
    end
    best_expression = nothing 
    best_program = start_program
    program_cost = Inf64
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
function generic_run(::Type{Parallel}, meta_search_list::Vector; start_program::Union{Nothing,RuleNode} = nothing)
    # create an inital random program as the start
    if isnothing(start_program)
        start_program = rand(RuleNode, arithmetic_grammar, :X, 2)
    end
    best_expression = nothing 
    best_program = start_program
    program_cost = Inf64
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

# GENERATE META SEARCH PROCEDURE AND RUN IT
meta_expression = rulenode2expr(rand(RuleNode, grammar, :S, 14), grammar)

println(meta_expression)
@time expr,_,_ = eval(meta_expression)
println("Expr found: $expr")


