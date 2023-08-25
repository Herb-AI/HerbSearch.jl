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

"""
Expression is an expression like x * x + x * x * x - 5 and max_depth is the max depth
"""
macro testmh(expression::String, max_depth=6)
    return :(
        @testset "mh $($expression)" begin
        e = Meta.parse("x -> $($expression)")
        problem, examples = create_problem(eval(e))
        enumerator = get_mh_enumerator(examples, mean_squared_error)
        program, cost = search_best(grammar, problem, :X, enumerator=enumerator, error_function=mse_error_function, max_depth=$max_depth, max_time=MAX_RUNNING_TIME)
        @test cost == 0
    end
    )
end

const global MAX_RUNNING_TIME = 10
macro testsa(expression::String,max_depth=6,init_temp = 2)
    return :(
        @testset "sa $($expression)" begin
        e = Meta.parse("x -> $($expression)")
        problem, examples = create_problem(eval(e))
        enumerator = get_sa_enumerator(examples, mean_squared_error, $init_temp)
        program, cost = search_best(grammar, problem, :X, enumerator=enumerator, error_function=mse_error_function, max_depth=$max_depth, max_time=MAX_RUNNING_TIME)
        @test cost == 0
    end
    )
end

macro testvlsn(expression::String, max_depth = 6, enumeration_depth = 2)
    return :(
        @testset "vl $($expression)" begin
        e = Meta.parse("x -> $($expression)")
        problem, examples = create_problem(eval(e))
        enumerator = get_vlsn_enumerator(examples, mean_squared_error, $enumeration_depth)
        program, cost = search_best(grammar, problem, :X, enumerator=enumerator, error_function=mse_error_function, max_depth=$max_depth, max_time=MAX_RUNNING_TIME)
        @test cost == 0
    end
    )
end

@testset verbose = true "Algorithms" begin
    @testset verbose = true "MH" begin
        @testmh "x * x + 4" 3
        @testmh "x * (x + 5)" 4


        @testset verbose = true "factorization" begin
            @testmh  "5 * 5 * 5"         3  # 125 = 5 * 5 * 5 (depth 3)
            # @testmh  "5 * 5 * 5 * 5"     3  # 625 = 5 * 5 * 5 * 5 (depth 3)
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
            @testsa  "5 * 5"             2  # 25 = 5 * 5 (depth 2)
            @testsa  "2 * 3 * 4"         3  # (depth 3)
        end
    end
end