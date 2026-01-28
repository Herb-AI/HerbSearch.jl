using HerbGrammar, HerbCore, HerbSpecification

struct MockProblem end

mutable struct MockGrammar
    dummy:: Int
end

struct FakeRuleNode
    id::Int
end

fake_stop_checker = function(timed_solution)
    return false
end

fake_synth_fn = function(problem, iter)
    global fake_state
    prog = FakeRuleNode(fake_state)
    result = fake_state % 2 == 0 ? optimal_program : suboptimal_program
    return (prog, result)
end

fake_selector = results -> results[end]

fake_updater = function(selected, iter)
    global fake_state += 1
    return iter
end

grammar = @csgrammar begin
    Number = 1
    Number = 2
    Number = 3
    Number = Number + Number
end

@testset verbose=true "BudgetedSearch Tests with BFSIterator" begin
    global fake_state = 1
    problem, examples = create_problem(x -> x)
    iterator = BFSIterator(grammar, :Number, max_depth=4)


    ctrl = BudgetedSearchController(
        problem=problem,
        iterator=iterator,
        synth_fn=fake_synth_fn,
        stop_checker=fake_stop_checker,
        attempts=3,
        selector=fake_selector,
        updater=fake_updater
    )

    @test ctrl.problem==problem
    @test ctrl.iterator==iterator

    results, times, total = run_budget_search(ctrl)

    # Results should be tuples of (FakeRuleNode, SynthResult)
    @test length(results) == 3
    @test all(x -> x isa Tuple{FakeRuleNode, SynthResult}, results)

    # Check correct returned values
    # iterator.state: 1, 2, 3 → results will be:
    # (FakeRuleNode(1), suboptimal_program)
    # (FakeRuleNode(2), optimal_program)
    # (FakeRuleNode(3), suboptimal_program)
    @test results[1][1].id == 1 && results[1][2] == suboptimal_program
    @test results[2][1].id == 2 && results[2][2] == optimal_program
    @test results[3][1].id == 3 && results[3][2] == suboptimal_program


end

