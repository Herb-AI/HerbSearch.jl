include("benchmark_helpers.jl")
using HerbBenchmarks
using HerbBenchmarks.String_transformations_2020

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

@testset "Testing Aulile With String Benchmark" begin
    max_iterations = 2
    max_depth = 10
    max_enumerations = 1000
    total_start_time = print_time_test_start("Running Test: String 2020 Benchmark")
    problem_grammar_pairs = get_all_problem_grammar_pairs(String_transformations_2020)
    problem_grammar_pairs = first(problem_grammar_pairs, 10)
    init_grammar = problem_grammar_pairs[1].grammar
    # Solve problems
    programs = Vector{RuleNode}([])

    regular_passed_tests = 0
    aulile_passed_tests = 0
    for (i, pg) in enumerate(problem_grammar_pairs)
        grammar = deepcopy(init_grammar)
        id = pg.identifier
        problem = pg.problem
        print_time_test_start("Problem $i (id = $id)", print_separating_dashes=false)

        regular_synth_start_time = print_time_test_start("\n\tRegular Synth Results:\n",
            print_separating_dashes=false)
        regular_synth_result = synth_with_aux(problem, BFSIterator(grammar, :Start, max_depth=max_depth),
            grammar, default_aux, typemax(Int),
            interpret=HerbBenchmarks.String_transformations_2020.interpret,
            allow_evaluation_errors=true, max_enumerations=max_enumerations)

        if is_test_passed_and_debug(regular_synth_result, grammar, 0, regular_synth_start_time)
            regular_passed_tests += 1
        end

        aulile_start_time = print_time_test_start("\n\tAulile Results:\n", print_separating_dashes=false)
        aulile_result = aulile(problem, BFSIterator, grammar, :Start, levenshtein_benchmark_aux,
            interpret=HerbBenchmarks.String_transformations_2020.interpret,
            allow_evaluation_errors=true,
            max_iterations=max_iterations, max_depth=max_depth,
            max_enumerations=(max_enumerations / max_iterations))

        if is_test_passed_and_debug(aulile_result, grammar, optimal_program, aulile_start_time)
            aulile_passed_tests += 1
        end

        println("------------------------")
    end

    println()
    println("Without Aulile Passed: $(regular_passed_tests)/$(length(problem_grammar_pairs)) tests.")
    println("With Aulile Passed: $(aulile_passed_tests)/$(length(problem_grammar_pairs)) tests.")
    print_time_test_end(total_start_time, test_passed=(aulile_passed_tests == length(problem_grammar_pairs)))
end


