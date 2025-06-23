using Markdown
using InteractiveUtils
using Random
using Dates
# include("RefactorExt.jl")
# using .RefactorExt
using HerbCore, HerbGrammar, HerbSearch, HerbSpecification, HerbBenchmarks
include("../src/aulile_auxiliary_functions.jl")


function run_benchmark_comparison(init_grammar::AbstractGrammar, problems::Vector{Problem}, 
        aux::AuxFunction, interpret::Function; 
        max_depth::Int, max_iterations::Int, max_enumerations::Int, allow_evaluation_errors=false)

    regular_passed_tests = 0
    aulile_passed_tests = 0

    println("Problem: Reg_solved_flag, Reg_enums; Aulile_solved_flag, Aulile_enums")
    for (i, problem) in enumerate(problems)
        print("Problem ", i, ": ")
        grammar = deepcopy(init_grammar)

        program, new_score, enumerations = synth_with_aux(problem, 
            BFSIterator(grammar, :Start, max_depth=max_depth), grammar, default_aux, 
            Dict{Int64, AbstractRuleNode}(), typemax(Int),
            interpret=interpret,
            allow_evaluation_errors=allow_evaluation_errors, max_enumerations=max_enumerations)

        passed = !isnothing(program) && new_score <= 0  # Optimum assumed 0
        print(Int(passed), ", ") 
        print(enumerations, "; ")
        if passed
            regular_passed_tests += 1
        end

        program, program_optimality, enumerations = aulile(problem, BFSIterator, grammar, :Start, 
            :Operation, aux, interpret=interpret, allow_evaluation_errors=allow_evaluation_errors,
            max_iterations=max_iterations, max_depth=max_depth,
            max_enumerations=(max_enumerations / max_iterations))

        passed = !isnothing(program) && program_optimality == optimal_program
        print(Int(passed), ", ") 
        print(enumerations)
        if passed
            aulile_passed_tests += 1
        end
        println()
    end
    println()
    
    @assert regular_passed_tests <= length(problems)
    @assert aulile_passed_tests <= length(problems)

    return regular_passed_tests, aulile_passed_tests
end

function experiment_main(problem_name::AbstractString, 
        max_depth::Int, max_iterations::Int, max_enumerations::Int)    
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    dir_path = dirname(@__FILE__)
    res_path = joinpath(dir_path, "compairson_results")
    mkpath(res_path)
    res_file_name = "$(problem_name)_$(max_depth)_$(max_iterations)_$(max_enumerations)_$(timestamp).txt"
    res_file_path = joinpath(res_path, res_file_name)

    # open results file and redirect STDIO
    open(res_file_path, "w") do io
        redirect_stdout(io) do
            benchmark = get_benchmark(problem_name)
            problems = get_all_problems(benchmark)
            init_grammar = get_default_grammar(benchmark)
            aux = get_aux_function(problem_name)
            regular_passed_tests, aulile_passed_tests = run_benchmark_comparison(init_grammar, 
                problems, aux, benchmark.interpret, 
                max_depth=max_depth, max_iterations=max_iterations, max_enumerations=max_enumerations)

            println("Regular,Aulile")
            println(round(regular_passed_tests / length(problems); digits=2), ",", 
                round(aulile_passed_tests / length(problems); digits=2))
        end
    end
end


function get_benchmark(problem_name::String)
    if problem_name == "strings"
        return HerbBenchmarks.String_transformations_2020
    elseif problem_name == "robots"
        return Robots_2020
    elseif problem_name == "pixels"
        return HerbBenchmarks.Pixels_2020
    elseif problem_name == "bitvectors"
        return HerbBenchmarks.PBE_BV_Track_2018
    else
        return HerbBenchmarks.String_transformations_2020
    end
end


experiment_main(ARGS[1], parse(Int, ARGS[2]), parse(Int, ARGS[3]), parse(Int, ARGS[4]))