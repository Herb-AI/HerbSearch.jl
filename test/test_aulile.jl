# Function added from levenstein library: [https://github.com/rawrgrr/Levenshtein.jl/blob/master/src/Levenshtein.jl]
function levenshtein!(
    source::AbstractString,
    target::AbstractString,
    deletion_cost::R,
    insertion_cost::S,
    substitution_cost::T,
    costs::Matrix=Array{promote_type(R, S, T)}(undef, 2, length(target) + 1)
) where {R<:Real,S<:Real,T<:Real}
    cost_type = promote_type(R, S, T)
    if length(source) < length(target)
        # Space complexity of function = O(length(target))
        return levenshtein!(target, source, insertion_cost, deletion_cost, substitution_cost, costs)
    else
        if length(target) == 0
            return length(source) * deletion_cost
        else
            old_cost_index = 1
            new_cost_index = 2

            costs[old_cost_index, 1] = 0
            for i in 1:length(target)
                costs[old_cost_index, i+1] = i * insertion_cost
            end

            i = 0
            for r in source
                i += 1

                # Delete i characters from source to get empty target
                costs[new_cost_index, 1] = i * deletion_cost

                j = 0
                for c in target
                    j += 1

                    deletion = costs[old_cost_index, j+1] + deletion_cost
                    insertion = costs[new_cost_index, j] + insertion_cost
                    substitution = costs[old_cost_index, j]
                    if r != c
                        substitution += substitution_cost
                    end

                    costs[new_cost_index, j+1] = min(deletion, insertion, substitution)
                end

                old_cost_index, new_cost_index = new_cost_index, old_cost_index
            end

            new_cost_index = old_cost_index
            return costs[new_cost_index, length(target)+1]
        end
    end
end

using Dates

"""
    Prints test message (name) and returns the start time
"""
function print_time_test_start(message::AbstractString; print_separating_dashes=true)::DateTime
    if print_separating_dashes
        println()
        println("--------------------------------------------------")
    end
    printstyled(message * "\n"; color=:blue)
    if print_separating_dashes
        println("--------------------------------------------------")
    end
    return Dates.now()
end

"""
    Prints and returns the duration of the test
"""
function print_time_test_end(start_time::DateTime; end_time::DateTime=Dates.now(), test_passed=true)::DateTime
    duration = max(end_time - start_time, Dates.Millisecond(0))
    println()
    if test_passed
        printstyled("Pass. Duration: "; color=:green)
    else
        printstyled("Fail. Duration: "; color=:red)
    end
    println("$(duration)")
    return duration
end

simple_grammar = @csgrammar begin
    String = " "
    String = "<"
    String = ">"
    String = "-"
    String = "."
    String = x
    String = String * String
    String = replace(String, String => "")
end

function levenshtein_string(
    expected::IOExample{<:Any,<:AbstractString},
    actual::AbstractString)::Int
    return levenshtein!(expected.out, actual, 1, 1, 1) # Equal costs for each mistake type
end

@testset "Example Appending" begin
    start_time = print_time_test_start("Running Test: Example Appending")
    problem = Problem([
        IOExample(Dict(:x => "1"), "1."),
        IOExample(Dict(:x => "2"), "2."),
        IOExample(Dict(:x => "3"), "3.")
    ])
    test_result = aulile(problem, BFSIterator, simple_grammar, :String,
        AuxFunction(levenshtein_string, 0))
    @test !(test_result isa Nothing)
    solution, flag = test_result
    @test !(solution isa Nothing)
    @test flag == optimal_program
    program = rulenode2expr(solution, simple_grammar)
    println(program)
    print_time_test_end(start_time)
end

@testset "Example Replacing" begin
    start_time = print_time_test_start("Running Test: Example Replacing")
    problem = Problem([
        IOExample(Dict(:x => "1."), "1"),
        IOExample(Dict(:x => "2."), "2"),
        IOExample(Dict(:x => "3."), "3")
    ])
    test_result = aulile(problem, BFSIterator, simple_grammar, :String,
        AuxFunction(levenshtein_string, 0))
    @test !(test_result isa Nothing)
    solution, flag = test_result
    program = rulenode2expr(solution, simple_grammar)
    println(program)
    @test !(solution isa Nothing)
    print_time_test_end(start_time)
end

@testset "Aulile Example from Paper" begin
    start_time = print_time_test_start("Running Test: Aulile Example from Paper")
    problem = Problem([
        IOExample(Dict(:x => "801-456-8765"), "8014568765"),
        IOExample(Dict(:x => "<978> 654-0299"), "9786540299"),
        IOExample(Dict(:x => "978.654.0299"), "9786540299")
    ])
    test_result = aulile(problem, BFSIterator, simple_grammar, :String,
        AuxFunction(levenshtein_string, 0), max_depth=2)
    @test !(test_result isa Nothing)
    solution, flag = test_result
    program = rulenode2expr(solution, simple_grammar)
    println(program)
    print_time_test_end(start_time)
end

using HerbBenchmarks
using HerbBenchmarks.String_transformations_2020

"""
    Default auxiliary function of just checking how many tests are correct.
"""
function is_test_correct(
    expected::IOExample{<:Any,<:HerbBenchmarks.String_transformations_2020.StringState},
    actual::HerbBenchmarks.String_transformations_2020.StringState)::Int
    if expected.out.str == actual.str
        return 0
    else
        return 1
    end
end

function levenshtein_string_state(
    expected::IOExample{<:Any,<:HerbBenchmarks.String_transformations_2020.StringState},
    actual::HerbBenchmarks.String_transformations_2020.StringState)::Int
    return levenshtein!(expected.out.str, actual.str, 1, 1, 1) # Equal costs for error types
end

"""
    Prints debugging information and returns whether the test passed
"""
function is_test_passed_and_debug(test_res::Union{Tuple{RuleNode,Any},Nothing}, grammar::AbstractGrammar,
    optimal_score::Any, start_time::DateTime, end_time::DateTime=Dates.now())::Bool
    if !isnothing(test_res)
        solution, score = test_res
        passed = score <= optimal_score
        if passed
            print_time_test_end(start_time, end_time=end_time)
        else
            println("Suboptimal program")
            print_time_test_end(start_time, end_time=end_time,
                test_passed=false)
        end
        println(rulenode2expr(solution, grammar))
        return passed
    else
        print_time_test_end(start_time, end_time=end_time,
            test_passed=false)
        return false
    end
end

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
            grammar, AuxFunction(is_test_correct, 0), typemax(Int),
            HerbBenchmarks.String_transformations_2020.interpret,
            HerbBenchmarks.String_transformations_2020.get_relevant_tags;
            allow_evaluation_errors=true, max_enumerations=max_enumerations)

        if is_test_passed_and_debug(regular_synth_result, grammar, 0, regular_synth_start_time)
            regular_passed_tests += 1
        end

        aulile_start_time = print_time_test_start("\n\tAulile Results:\n", print_separating_dashes=false)
        aulile_result = aulile(problem, BFSIterator, grammar, :Start, AuxFunction(levenshtein_string_state, 0),
            interpret=HerbBenchmarks.String_transformations_2020.interpret,
            get_relevant_tags=HerbBenchmarks.String_transformations_2020.get_relevant_tags,
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


