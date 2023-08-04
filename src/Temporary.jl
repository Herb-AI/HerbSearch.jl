using HerbGrammar
using HerbConstraints
using HerbEvaluation
using HerbSearch
using HerbData


arithmetic_grammar = @csgrammar begin
    X = |(1:5)
    X = X * X
    X = X + X
    X = X - X
    X = x
end

grammar = @csgrammar begin
    # S = run(A...)
    S = COMBINATOR
    MS = A
    MS = COMBINATOR
    A = mh(),STOPFUNCTION
    # A = vlns,STOP
    # A = sa,STOP
    # A = ga,STOP
    # A = dfs,STOP
    # A = bfs,STOP
    # A = astar,STOP
    # MHCONFIGURATION = MAXDEPTH
    # MAXDEPTH = 3
    COMBINATOR = sequence(ALIST)
    ALIST = [A]
    ALIST = [A,ALIST]
    # COMBINATOR = sequence(MSLIST)
    # COMBINATOR = parallel([MSLIST],SELECT)
    # MSLIST = MS,MS
    # MSLIST = MS,MSLIST
    # SELECT = best | crossover | mutate
    STOPFUNCTION = (time, iteration, cost) -> STOPCONDITION
    STOPCONDITION = STOPTERM
    # STOPCONDITION = STOPTERM && STOPCONDITION
    # STOPTERM = OPERAND == VALUE
    STOPTERM = OPERAND > VALUE
    # STOPTERM = OPERAND < VALUE
    # OPERAND = time | iteration | cost
    OPERAND = iteration
    VALUE = |(1:10)
    VALUE = 10 * VALUE
end

# CREATE A PROBLEM
function create_problem(f, range=20)
    examples = [HerbData.IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
    return HerbData.Problem(examples), examples
end

problem, examples = create_problem(x -> x * x * x + x * x + 2 * x + 5)

# HELPER FUNCTIONS
function mh()
    enumerator = HerbSearch.get_mh_enumerator(examples, HerbSearch.mean_squared_error)
    return enumerator
end

function run(enumerator::Function, stopping_condition::Function; start_program::RuleNode=rand(RuleNode, arithmetic_grammar, :X, 2))
    program, rulenode, cost = HerbSearch.supervised_search(arithmetic_grammar, problem, :X, stopping_condition, start_program, enumerator=enumerator, error_function=HerbSearch.mse_error_function)
    return program, rulenode
end

""" 
recursive flatten an array
"""
function flatten(arr)
    while any(a -> a isa Array, arr)
        arr = vcat(arr...)
    end
    arr
end


function sequence(algorithm_list)
    algorithm_list = flatten(algorithm_list) # first flatten the list
    # create an inital random program as the start
    start_program = rand(RuleNode, arithmetic_grammar, :X, 2)
    for (enumerator, stopping_condition) ∈ algorithm_list
        println("stopping condition", stopping_condition)
        program, start_program = run(enumerator, stopping_condition, start_program = start_program)
    end
end

# GENERATE META SEARCH PROCEDURE AND RUN IT
meta_expression = rulenode2expr(rand(RuleNode, grammar, :S, 8), grammar)

print(meta_expression)

@time print(eval(meta_expression))
