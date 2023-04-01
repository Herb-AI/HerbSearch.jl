using Logging
disable_logging(LogLevel(1))


function create_problem(f, range=10)
    examples = [Herb.HerbData.IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
    return Herb.HerbData.Problem(examples, "example"), examples
end

grammar = @cfgrammar begin
    C = |(1:5)
    X = |(1:5)
    X = C * X
    X = X + X
    X = X - X
    X = X * X
    X = x
end

"""
Expression is an expression like x * x + x * x * x - 5 and max_depth is the max depth
"""
macro testmh(expression::String, max_depth=6)
    return :(
        @testset "test Metropolis Hastings $($expression)" begin
        e = Meta.parse("x -> $($expression)")
        problem, examples = create_problem(eval(e))
        enumerator = HerbSearch.get_mh_enumerator(grammar, examples, $max_depth, :X, HerbSearch.mean_squared_error)
        found = Herb.HerbSearch.search_it(grammar, problem, enumerator)
        println("Wanted $($expression) => Found $found")
    end
    )
end

@testset verbose = true "Algorithms" begin
    @testset verbose = true "MH" begin

        @testmh "x * x + 4" 3
        @testmh "x * (x + 5) + 2" 4
        @testmh "x * (x + 25) + 5" 6
        # @testmh "x * (x + 25) + 101" 5 <- tests takes a long time to run

        # @testset "test Metropolis Hastings x * (x + 25) + 101" begin
        #     problem, examples = create_problem(x -> x * (x + 25) + 101)
        #     enumerator = HerbSearch.get_mh_enumerator(grammar, examples, 6, :X, HerbSearch.mean_squared_error)
        #     println("Found ", Herb.HerbSearch.search_it(grammar, problem, enumerator))
        # end

        function test_factor_out(number, max_depth::Int64)
            problem, examples = create_problem(x -> number)
            enumerator = HerbSearch.get_mh_enumerator(grammar, examples, max_depth, :X, HerbSearch.mean_squared_error)
            println("Found ", Herb.HerbSearch.search_it(grammar, problem, enumerator))
        end

        @testset verbose = true "factorization" begin
            @testset "125 = 5 * 5 * 5" begin
                test_factor_out(125, 3)
            end
            @testset "625 = 5 * 5 * 5 * 5" begin
                test_factor_out(125, 3)
            end
            @testset "150 = 2 * 3 * 5 * 5" begin
                test_factor_out(150, 3)
            end

        end
    end
end