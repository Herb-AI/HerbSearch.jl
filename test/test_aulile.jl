include("../src/aulile_auxiliary_functions.jl")

levenshtein_aux = AuxFunction(
    (expected::IOExample{<:Any,<:AbstractString}, actual::AbstractString) ->
        levenshtein!(expected.out, actual, 1, 1, 1),
    problem::Problem -> begin
        score = 0
        for example ∈ problem.spec
            score += levenshtein!(example.out, only(values(example.in)), 1, 1, 1)
        end
        return score
    end,
    0
)

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

@testset "Example Appending" begin
    start_time = print_time_test_start("Running Test: Example Appending")
    problem = Problem([
        IOExample(Dict(:x => "1"), "1."),
        IOExample(Dict(:x => "2"), "2."),
        IOExample(Dict(:x => "3"), "3.")
    ])
    test_result = aulile(problem, BFSIterator, simple_grammar, :String, :String, levenshtein_aux)
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
    test_result = aulile(problem, BFSIterator, simple_grammar, :String, :String, levenshtein_aux)
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
    test_result = aulile(problem, BFSIterator, simple_grammar, :String, :String, levenshtein_aux, max_depth=2)
    @test !(test_result isa Nothing)
    solution, flag = test_result
    program = rulenode2expr(solution, simple_grammar)
    println(program)
    print_time_test_end(start_time)
end

