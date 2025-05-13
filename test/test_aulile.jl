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

function print_time_test_start(test_name::AbstractString)::DateTime
    println("--------------------------------------------------")
    printstyled("Running Test: "; color=:blue)
    println("$test_name")
    println("--------------------------------------------------")
    return Dates.now()
end

function print_time_test_end(start_time::DateTime)::DateTime
    duration = max(Dates.now() - start_time, Dates.Millisecond(0))
    printstyled("\nPass. Duration: "; color=:green)
    println("$(duration)\n")
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
    start_time = print_time_test_start("Example Appending")
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
    start_time = print_time_test_start("Example Replacing")
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
    start_time = print_time_test_start("Aulile Example from Paper")
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

function levenshtein_string_state(
    expected::IOExample{<:Any,<:HerbBenchmarks.String_transformations_2020.StringState},
    actual::HerbBenchmarks.String_transformations_2020.StringState)::Int
    return levenshtein!(expected.out.str, actual.str, 1, 1, 1) # Equal costs for each mistake type
end

@testset "Testing Aulile With String Benchmark" begin
    start_time = print_time_test_start("String 2020 Benchmark")
    problem_grammar_pairs = get_all_problem_grammar_pairs(String_transformations_2020)
    # problem_grammar_pairs = first(problem_grammar_pairs, 20)
    grammar = problem_grammar_pairs[1].grammar

    println("Initial grammar:")
    println(grammar)

    # Solve problems
    programs = Vector{RuleNode}([])

    for (i, pg) in enumerate(problem_grammar_pairs)
        problem = pg.problem
        test_result = aulile(problem, BFSIterator, grammar, :Start, AuxFunction(levenshtein_string_state, 0),
            interpret=HerbBenchmarks.String_transformations_2020.interpret,
            get_relevant_tags=HerbBenchmarks.String_transformations_2020.get_relevant_tags)

        if !isnothing(test_result)
            solution, flag = test_result
            id = pg.identifier
            println("\nProblem $i (id = $id)")
            println("Solution found: ", solution)
            push!(programs, solution)
        end
        println("------------------------\n")
    end

    print_time_test_end(start_time)
end


