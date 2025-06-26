include("benchmark_helpers.jl")
include("../src/aulile_auxiliary_functions.jl")
using HerbBenchmarks

using HerbBenchmarks.String_transformations_2020

@testset "String Benchmark" begin
    max_depth = 10
    max_iterations = 3
    max_enumerations = 1_000

    aux = AUX_FUNCTIONS["strings"]["aulile_edit_distance"]
    run_benchmark("String 2020 Benchmark", get_default_grammar(String_transformations_2020),
        first(get_all_problems(String_transformations_2020), 10), get_all_identifiers(String_transformations_2020),
        aux, :Operation, HerbBenchmarks.String_transformations_2020.interpret,
        max_depth=max_depth, max_iterations=max_iterations, max_enumerations=max_enumerations,
        allow_evaluation_errors=true)
end

using HerbBenchmarks.Karel_2018

@testset "Karel Benchmark" begin
    max_depth = 10
    max_iterations = 3
    max_enumerations = 1_000

    aux = AUX_FUNCTIONS["karel"]["aulile_edit_distance"]
    run_benchmark("Karel 2018 Benchmark", Karel_2018.grammar_karel,
        first(Karel_2018.get_all_problems(), 10), Vector{String}(),
        aux, :Action, HerbBenchmarks.Karel_2018.interpret,
        max_depth=max_depth, max_iterations=max_iterations, max_enumerations=max_enumerations,
        allow_evaluation_errors=false)
end

using HerbBenchmarks.Robots_2020

@testset "Robots Benchmark" begin
    max_depth = 10
    max_iterations = 3
    max_enumerations = 1_000

    aux = AUX_FUNCTIONS["robots"]["aulile_all_steps_manhattan"]
    run_benchmark("Robots 2020 Benchmark", get_default_grammar(Robots_2020),
        first(get_all_problems(Robots_2020), 10), get_all_identifiers(Robots_2020),
        aux, :Operation, HerbBenchmarks.Robots_2020.interpret,
        max_depth=max_depth, max_iterations=max_iterations, max_enumerations=max_enumerations,
        allow_evaluation_errors=false)
end

using HerbBenchmarks.Pixels_2020

@testset "Pixels Benchmark" begin
    max_depth = 10
    max_iterations = 3
    max_enumerations = 1_000

    aux = AUX_FUNCTIONS["pixels"]["aulile_edit_distance"]
    run_benchmark("Pixels 2020 Benchmark", get_default_grammar(Pixels_2020),
        first(get_all_problems(Pixels_2020), 10), get_all_identifiers(Pixels_2020),
        aux, :Operation, HerbBenchmarks.Pixels_2020.interpret,
        max_depth=max_depth, max_iterations=max_iterations, max_enumerations=max_enumerations,
        allow_evaluation_errors=false)
end