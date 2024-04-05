
using Logging
disable_logging(LogLevel(1))

function create_problem(f, range=20)
    examples = [IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
    return Problem(examples), examples
end

grammar = @csgrammar begin
    X = |(1:5)
    X = X * X
    X = X + X
    X = X - X
    X = x
end

addconstraint!(grammar, Forbidden(RuleNode(8, [VarNode(:a), VarNode(:a)])))                     # forbids "a - a"
addconstraint!(grammar, Forbidden(DomainRuleNode(BitVector((0, 1, 1, 1, 1, 0, 0, 0, 0)), [])))  # forbids 2, 3, 4 and 5
addconstraint!(grammar, Contains(9))                                                            # program must contain an "x"

@testset verbose = true "Stochastic with Constraints" begin
    #solution exists
    problem, examples = create_problem(x -> x * x)
    iterator = MHSearchIterator(grammar, :X, examples, mean_squared_error, max_depth=2, max_time=2)
    solution, flag = synth(problem, iterator)
    @test solution == RuleNode(6, [RuleNode(9), RuleNode(9)])
    @test flag == optimal_program

    #solution does not exist (no "x" is used)
    problem, examples = create_problem(x -> 1)
    iterator = MHSearchIterator(grammar, :X, examples, mean_squared_error, max_depth=2, max_time=1)
    solution, flag = synth(problem, iterator)
    @test flag == suboptimal_program

    #solution does not exist (the forbidden "a - a" is used)
    problem, examples = create_problem(x -> x - x)
    iterator = MHSearchIterator(grammar, :X, examples, mean_squared_error, max_depth=2, max_time=1)
    solution, flag = synth(problem, iterator)
    @test flag == suboptimal_program

    #solution does not exist (the program is too large, it exceeds max_depth=2)
    problem, examples = create_problem(x -> x * (x + 1))
    iterator = MHSearchIterator(grammar, :X, examples, mean_squared_error, max_depth=2, max_time=1)
    solution, flag = synth(problem, iterator)
    @test flag == suboptimal_program
end
