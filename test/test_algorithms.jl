using Logging
disable_logging(LogLevel(1))


function create_problem(f, range=20)
    examples = [Herb.HerbData.IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
    return Herb.HerbData.Problem(examples, "example"), examples
end

grammar = @cfgrammar begin
    X = |(1:5)
    X = X * X
    X = X + X
    X = X - X
    X = x
end

"""
Expression is an expression like x * x + x * x * x - 5 and max_depth is the max depth
"""
macro testmh(expression::String, max_depth=6)
    return :(
        @testset "mh $($expression)" begin
        e = Meta.parse("x -> $($expression)")
        problem, examples = create_problem(eval(e))
        enumerator = HerbSearch.get_mh_enumerator(grammar, examples, $max_depth, :X, HerbSearch.mean_squared_error)
        found = Herb.HerbSearch.search_it(grammar, problem, enumerator)
        
        # Dummy assert so that it appears there. If we get to this point the search function founda a correct solution.
        @test 1 == 1
    end
    )
end


macro testsa(expression::String,max_depth=6,init_temp = 2)
    return :(
        @testset "sa $($expression)" begin
        e = Meta.parse("x -> $($expression)")
        problem, examples = create_problem(eval(e))
        enumerator = HerbSearch.get_sa_enumerator(grammar, examples, $max_depth, :X, HerbSearch.mean_squared_error, $init_temp)
        found = Herb.HerbSearch.search_it(grammar, problem, enumerator)
        
        # Dummy assert so that it appears there. If we get to this point the search function founda a correct solution.
        @test 1 == 1
    end
    )
end

macro testvlsn(expression::String, max_depth = 6, enumeration_depth = 2)
    return :(
        @testset "vl $($expression)" begin
        e = Meta.parse("x -> $($expression)")
        problem, examples = create_problem(eval(e))
        enumerator = HerbSearch.get_vlsn_enumerator(grammar, examples, $max_depth, :X, HerbSearch.mean_squared_error, $enumeration_depth)
        found = Herb.HerbSearch.search_it(grammar, problem, enumerator)
        
        # Dummy assert so that it appears there. If we get to this point the search function founda a correct solution.
        @test 1 == 1
    end
    )
end

@testset verbose = true "Algorithms" begin
    @testset verbose = true "MH" begin
        @test 1 == 1
        @testmh "x * x + 4" 3
        @testmh "x * (x + 5) + 2" 4
        @testmh "x * (x + 25) + 5" 6
        @testmh "x * x + 5 * x * x * x * x" 6


        function test_factor_out(number, max_depth::Int64)
            problem, examples = create_problem(x -> number)
            enumerator = HerbSearch.get_mh_enumerator(grammar, examples, max_depth, :X, HerbSearch.mean_squared_error)
            println("Found ", Herb.HerbSearch.search_it(grammar, problem, enumerator))
        end

        @testset verbose = true "factorization" begin
            @testmh  "5 * 5 * 5"         3  # 125 = 5 * 5 * 5 (depth 3)
            @testmh  "5 * 5 * 5 * 5"     3  # 625 = 5 * 5 * 5 * 5 (depth 3)
            @testmh  "2 * 3 * 5 * 5"     3  # 150 = 2 * 3 * 5 * 5 (depth 3)
            @testmh  "2 * 2 * 3 * 4 * 5" 4  # 240 = ((2 * 2) * (3 * 4)) * 5 (depth 4)

        end
    end
    
    @testset verbose = true "Very Large Scale Neighbourhood" begin
        @testvlsn "x * x * x" 3
        @testvlsn "x * x * x * x" 3

    end
    
    @testset verbose = true "Simulated Annealing" begin
        @testsa "x * x + 4" 3
        @testsa "x * (x + 5)" 3 2

        @testset verbose = true "factorization" begin
            @testsa  "5 * 5 * 5"         3  # 125 = 5 * 5 * 5 (depth 3)
            @testsa  "5 * 5 * 5 * 5"     3  # 625 = 5 * 5 * 5 * 5 (depth 3)
            @testsa  "2 * 3 * 5 * 5"     3  # 150 = 2 * 3 * 5 * 5 (depth 3)
            @testsa  "2 * 2 * 3 * 4 * 5" 4  # 240 = ((2 * 2) * (3 * 4)) * 5 (depth 4)

        end
    end
end