using Logging
using LegibleLambdas
disable_logging(LogLevel(1))


function create_problem(f, range=20)
    examples = [IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
    return Problem(examples, "example"), examples
end

grammar = @cfgrammar begin
    X = |(1:5)
    X = X * X
    X = X + X
    X = X - X
    X = X ^ X
    X = x
end

@testset "test if random_mutate! always changes the program" verbose=true begin
    @testset "a specific program of depth 2" begin
        for i in 1:10
            ruleNode = RuleNode(6,[RuleNode(1),RuleNode(2)])
            before = deepcopy(ruleNode)
            HerbSearch.random_mutate!(ruleNode,grammar)
            @test ruleNode !== before
        end
    end
    @testset "only root node" begin
        root = RuleNode(1)
        HerbSearch.random_mutate!(root,grammar)
        @test root !== RuleNode(1)
    end
end

@testset "Cross over" begin
    @testset "outcome has 2 children" begin
        @testset "only rule nodes" begin
            @testset "two different roots get swapped" begin
                root1 = RuleNode(1)
                root2 = RuleNode(2)
                # they should be swapped
                @test HerbSearch.crossover_2_children(root1,root2) == (root2, root1)
                # no modification
                @test root1 == RuleNode(1)
                @test root2 == RuleNode(2)
            end

            @testset "crossing over the same rulenode gives the same rulenode two times" begin 
                @test HerbSearch.crossover_2_children(RuleNode(1),RuleNode(1)) == (RuleNode(1),RuleNode(1))
            end
        end

        @testset "crossing over two parents return two different children" begin

            rulenode1 = RuleNode(1,[RuleNode(2)])
            rulenode2 = RuleNode(3,[RuleNode(4,[RuleNode(5)])])
            child1,child2 = crossover_2_children(rulenode1,rulenode2)
            println(child1,child2)
            @test child1 !== child2
            @test rulenode1 == RuleNode(1,[RuleNode(2)])
            @test rulenode2 == RuleNode(3,[RuleNode(4,[RuleNode(5)])])
        end
    end
    @testset "having 1 child" begin
        @testset "only root node" begin
            @testset "crossing over the same rulenode gives the same rulenode" begin 
                @test HerbSearch.crossover_1_child(RuleNode(1),RuleNode(1)) == RuleNode(1)
            end

            @testset "crossing over the two roots gives one of them" begin 
                root1 = RuleNode(1)
                root2 = RuleNode(2)
                child = HerbSearch.crossover_1_child(root1, root2)
                @test (child == root1 || child == root2)
                @test root1 == RuleNode(1) && root2 == RuleNode(2)
            end
        end
        @testset "not root" begin
            root1 = RuleNode(1,[RuleNode(2)])
            root2 = RuleNode(3,[RuleNode(4)])
            child = HerbSearch.crossover_1_child(root1, root2)
        end

    end
end

@testset "simple expressions" verbose = true begin

    function fitness(program, results)
        1 / mean_squared_error(results)
    end

    grammar = @csgrammar begin
        X = |(1:5)
        X = X * X
        X = X + X
        X = X - X
        X = x
    end

    functions = [
        @λ(x -> 1),
        @λ(x -> 10),
        @λ(x -> 625),
        @λ(x -> 325),
        @λ(x -> 3 * x),
        @λ(x -> 3 * x + 10),
        @λ(x -> 3 * x * x + 2),
        @λ(x -> 3 * x * x + (x + 2)),
    ]
    function pretty_print_lambda(lambda)
        return repr(lambda)[2:end - 1]
    end

    @testset "testing $(pretty_print_lambda(f))" for f in functions
        problem, examples = create_problem(f)
        enumerator = get_genetic_enumerator(examples, 
            fitness_function = fitness, 
            initial_population_size = 10,
            mutation_probability = 0.8,
            maximum_initial_population_depth = 3)
        program, cost = search_best(grammar, problem, :X, enumerator=enumerator, error_function=mse_error_function, max_depth=nothing, max_time=20)
        @test cost == 0
    end
end