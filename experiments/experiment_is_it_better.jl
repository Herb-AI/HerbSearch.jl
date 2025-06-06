using Markdown
using InteractiveUtils
using Random
using Dates
include("../ext/RefactorExt/RefactorExt.jl")
using .RefactorExt
include("../src/HerbSearch.jl")
using HerbCore, HerbGrammar, .HerbSearch, HerbSpecification, HerbBenchmarks
include("utils.jl")

function experiments_main(
    problem_name::String, 
    using_mth::Int,
    k::Int, 
    time_out::Int # in seconds
)    
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    SHUFFLE_KEY = 1234
    rng = MersenneTwister(SHUFFLE_KEY)
    dir_path = dirname(@__FILE__)
    res_path = joinpath(dir_path, "results")
    mkpath(res_path)
    res_file_name = "Testing_improvement_$(problem_name)_Frac_$(using_mth)_K-$(k)_t_$(time_out)_$(timestamp).txt"
    res_file_path = joinpath(res_path, res_file_name)

    # open results file and redirect STDIO
    open(res_file_path, "w") do io
        redirect_stdout(io) do
        end
            println("Problem set: $(problem_name)\nUsing $(using_mth) fraction\nK = $(k)\tTimeout: $(time_out)\n")
            # get mth fraction of the problems
            benchmark = get_benchmark(problem_name)
            problem_grammar_pairs = get_all_problem_grammar_pairs(benchmark)
            compress, rest = split_problems(problem_grammar_pairs, using_mth)
            grammar = problem_grammar_pairs[1].grammar
            solutions = Vector{RuleNode}([])
            # solve prolems
            for p in compress
                problem = p.spec
                if problem_name == "bitvectors"
                    gr_key = :Start
                else
                    gr_key = :Sequence
                end
                iterator = HerbSearch.DFSIterator(grammar, gr_key, max_depth=7) 
                program = synth_program(problem, grammar, iterator, benchmark, problem_name)

                if !isnothing(program)
                    push!(solutions, program)
                end
            end
            # refactor_solutions
            optimiszed_grammar = RefactorExt.HerbSearch.refactor_grammar(
                solutions, grammar, k, k*15, time_out)
            synthesize_and_time(rest, optimiszed_grammar, benchmark, problem_name)
        # end
    end
end

function synthesize_and_time(problems::Vector{Any},
    grammar::ContextSensitiveGrammar,
    benchmark::Module, problem_name::String)
    time_all = Millisecond(Time(now())).value

    for problem in problems
        spec = problem.spec
        gr_key = :Start # starting from "start" here because we don't need to refactor now
        iterator = HerbSearch.DFSIterator(grammar, gr_key, max_depth=8) 
        program::RuleNode = synth_program(spec, grammar, iterator, benchmark, problem_name)
        println("Tree size $(get_size_of_a_tree(program))")
    end
    println("Total time (ms) $(Millisecond(Time(now())).value-time_all)")
end

function baseline_run(problem_name::String)
timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    SHUFFLE_KEY = 1234
    rng = MersenneTwister(SHUFFLE_KEY)
    dir_path = dirname(@__FILE__)
    res_path = joinpath(dir_path, "results")
    mkpath(res_path)
    res_file_name = "Baseline_for_$(problem_name)  $(timestamp).txt"
    res_file_path = joinpath(res_path, res_file_name)

    # open results file and redirect STDIO
    open(res_file_path, "w") do io
        redirect_stdout(io) do
            println("Problem set: $(problem_name)\n")
            # get mth fraction of the problems
            benchmark = get_benchmark(problem_name)
            problem_grammar_pairs = get_all_problem_grammar_pairs(benchmark)
            grammar = problem_grammar_pairs[1].grammar
            synthesize_and_time(problem_grammar_pairs, grammar, benchmark, problem_name)
        end
    end
end

println("strings")
# baseline_run("strings")
experiments_main("strings", 1, 3, 10) 