include("benchmark_helpers.jl")
using HerbBenchmarks
using HerbBenchmarks.Karel_2018

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

@testset "Karel Benchmark" begin
    max_iterations = 2
    max_depth = 10
    max_enumerations = 10000
    total_start_time = print_time_test_start("Karel 2018 Benchmark")
    problems = Karel_2018.get_all_problems()
    problems = first(problems, 10)
    init_grammar = Karel_2018.grammar_karel
    
    programs = Vector{RuleNode}([])

    regular_passed_tests = 0
    aulile_passed_tests = 0
    for (i, problem) in enumerate(problems)
        grammar = deepcopy(init_grammar)
        print_time_test_start("Problem $i: ", print_separating_dashes=false)

        regular_synth_start_time = print_time_test_start("\n\tRegular Synth Results:\n",
            print_separating_dashes=false)
        regular_synth_result = synth_with_aux(problem, BFSIterator(grammar, :Start, max_depth=max_depth),
            grammar, default_aux, typemax(Int),
            interpret=HerbBenchmarks.Karel_2018.interpret,
            allow_evaluation_errors=true, max_enumerations=max_enumerations)

        if is_test_passed_and_debug(regular_synth_result, grammar, 0, regular_synth_start_time)
            regular_passed_tests += 1
        end

        aulile_start_time = print_time_test_start("\n\tAulile Results:\n", print_separating_dashes=false)
        aulile_result = aulile(problem, BFSIterator, grammar, :Start, karel_benchmark_aux,
            interpret=HerbBenchmarks.Karel_2018.interpret,
            allow_evaluation_errors=true,
            max_iterations=max_iterations, max_depth=max_depth,
            max_enumerations=(max_enumerations / max_iterations))

        if is_test_passed_and_debug(aulile_result, grammar, optimal_program, aulile_start_time)
            aulile_passed_tests += 1
        end

        println("------------------------")
    end

    println()
    println("Without Aulile Passed: $(regular_passed_tests)/$(length(problems)) tests.")
    println("With Aulile Passed: $(aulile_passed_tests)/$(length(problems)) tests.")
    print_time_test_end(total_start_time, test_passed=(aulile_passed_tests == length(problems)))
end


