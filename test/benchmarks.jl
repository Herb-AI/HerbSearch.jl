include("benchmark_helpers.jl")
using HerbBenchmarks

del_cost = 1
insr_cost = 1
subst_cost = 1
levenshtein_benchmark_aux = AuxFunction(
    (expected::IOExample{<:Any,<:HerbBenchmarks.String_transformations_2020.StringState},
        actual::HerbBenchmarks.String_transformations_2020.StringState) ->
        levenshtein!(expected.out.str, actual.str, del_cost, insr_cost, subst_cost),
    problem::Problem -> begin
        score = 0
        for example ∈ problem.spec
            score += levenshtein!(example.out.str, only(values(example.in)).str, del_cost, insr_cost, subst_cost)
        end
        return score
    end,
    0
)

function karel_dist(expected::HerbBenchmarks.Karel_2018.KarelState, 
        actual::HerbBenchmarks.Karel_2018.KarelState)
    dist = sum(abs.(expected.hero.position .- actual.hero.position))
    dist += min(mod(Int(expected.hero.direction) - Int(actual.hero.direction), 4), 
        mod(Int(expected.hero.direction) + Int(actual.hero.direction), 4))

    all_positions = union(keys(expected.markers), keys(actual.markers))
    for pos in all_positions
        count_expected = get(expected.markers, pos, 0)
        count_actual = get(actual.markers, pos, 0)
        dist += abs(count_expected - count_actual)
    end
    return dist
end

karel_benchmark_aux = AuxFunction(
    (expected::IOExample{<:Any,<:HerbBenchmarks.Karel_2018.KarelState},
        actual::HerbBenchmarks.Karel_2018.KarelState) ->
        karel_dist(expected.out, actual),
    problem::Problem -> begin
        score = 0
        for example ∈ problem.spec
            score += karel_dist(example.out, only(values(example.in)))
        end
        return score
    end,
    0
)

function Base.:(==)(a::HerbBenchmarks.Robots_2020.RobotState, b::HerbBenchmarks.Robots_2020.RobotState)
    return a.holds_ball == b.holds_ball &&
           a.robot_x == b.robot_x &&
           a.robot_y == b.robot_y &&
           a.ball_x == b.ball_x &&
           a.ball_y == b.ball_y &&
           a.size == b.size
end

function robot_dist(expected::HerbBenchmarks.Robots_2020.RobotState, 
        actual::HerbBenchmarks.Robots_2020.RobotState)
    dist = abs(expected.holds_ball - actual.holds_ball)
    dist += abs(expected.robot_x - actual.robot_x)
    dist += abs(expected.robot_y - actual.robot_y)
    dist += abs(expected.ball_x - actual.ball_x)
    dist += abs(expected.ball_y - actual.ball_y)
    return dist
end

robot_benchmark_aux = AuxFunction(
    (expected::IOExample{<:Any,<:HerbBenchmarks.Robots_2020.RobotState},
        actual::HerbBenchmarks.Robots_2020.RobotState) ->
        robot_dist(expected.out, actual),
    problem::Problem -> begin
        score = 0
        for example ∈ problem.spec
            score += robot_dist(example.out, only(values(example.in)))
        end
        return score
    end,
    0
)

function pixel_dist(expected::HerbBenchmarks.Pixels_2020.PixelState, 
        actual::HerbBenchmarks.Pixels_2020.PixelState)
    if size(expected.matrix) != size(actual.matrix)
        error("Matrix sizes do not match.")
    end
    return count(expected.matrix .!= actual.matrix)
end

pixel_benchmark_aux = AuxFunction(
    (expected::IOExample{<:Any,<:HerbBenchmarks.Pixels_2020.PixelState},
        actual::HerbBenchmarks.Pixels_2020.PixelState) ->
        pixel_dist(expected.out, actual),
    problem::Problem -> begin
        score = 0
        for example ∈ problem.spec
            score += pixel_dist(example.out, only(values(example.in)))
        end
        return score
    end,
    0
)

using HerbBenchmarks.String_transformations_2020

@testset "String Benchmark" begin
    max_depth = 10
    max_iterations = 2
    max_enumerations = 1000

    run_benchmark("String 2020 Benchmark", get_default_grammar(String_transformations_2020), 
        first(get_all_problems(String_transformations_2020), 10), get_all_identifiers(String_transformations_2020), 
        levenshtein_benchmark_aux, HerbBenchmarks.String_transformations_2020.interpret, 
        max_depth=max_depth, max_iterations=max_iterations, max_enumerations=max_enumerations)
end

using HerbBenchmarks.Karel_2018

@testset "Karel Benchmark" begin
    max_iterations = 2
    max_depth = 10
    max_enumerations = 10000

    run_benchmark("Karel 2018 Benchmark", Karel_2018.grammar_karel, 
        first(Karel_2018.get_all_problems(), 10), Vector{String}(), 
        karel_benchmark_aux, HerbBenchmarks.Karel_2018.interpret, 
        max_depth=max_depth, max_iterations=max_iterations, max_enumerations=max_enumerations)
end

using HerbBenchmarks.Robots_2020

@testset "Robots Benchmark" begin
    max_depth = 10
    max_iterations = 2
    max_enumerations = 40000

    run_benchmark("Robots 2020 Benchmark", get_default_grammar(Robots_2020), 
        first(get_all_problems(Robots_2020), 10), get_all_identifiers(Robots_2020), 
        robot_benchmark_aux, HerbBenchmarks.Robots_2020.interpret, 
        max_depth=max_depth, max_iterations=max_iterations, max_enumerations=max_enumerations)
end

using HerbBenchmarks.Pixels_2020

@testset "Pixels Benchmark" begin
    max_depth = 10
    max_iterations = 2
    max_enumerations = 10000

    run_benchmark("Pixels 2020 Benchmark", get_default_grammar(Pixels_2020), 
        first(get_all_problems(Pixels_2020), 10), get_all_identifiers(Pixels_2020), 
        pixel_benchmark_aux, HerbBenchmarks.Pixels_2020.interpret, 
        max_depth=max_depth, max_iterations=max_iterations, max_enumerations=max_enumerations)
end