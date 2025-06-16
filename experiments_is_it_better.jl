using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using Markdown
using InteractiveUtils
using Random
using Dates
include("ext/RefactorExt/RefactorExt.jl")
using .RefactorExt
include("src/HerbSearch.jl")
using HerbCore, HerbGrammar, .HerbSearch, HerbSpecification, HerbBenchmarks
include("experiments/utils.jl")
include("experiments/grammar_constraints.jl")
include("experiments/synthesize.jl")
include("experiments/heuristics.jl")

function experiment_speedup_main(
    problem_name::String, 
    using_mth::Int,
    k::Int, 
    time_out::Int # in seconds
)    
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    dir_path = dirname(@__FILE__)
    res_path = joinpath(dir_path, "results")
    mkpath(res_path)
    res_file_name = "Testing_improvement_$(problem_name)_Frac_$(using_mth)_K-$(k)_t_$(time_out)_$(timestamp).txt"
    res_file_path = joinpath(res_path, res_file_name)

    # open results file and redirect STDIO
    open(res_file_path, "w") do io
        redirect_stdout(io) do
            println("Problem set: $(problem_name)\nUsing $(using_mth) fraction\nK = $(k)\tTimeout: $(time_out)\n")
            # get mth fraction of the problems
            benchmark = get_benchmark(problem_name)
            problem_grammar_pairs = get_all_problem_grammar_pairs(benchmark)
            # compress, rest = split_problems(problem_grammar_pairs, using_mth)
            compress_set, rest = take_mth_fraction(problem_grammar_pairs, 5, using_mth)
            grammar = get_constrained_string_grammar()
            optimiszed_grammar = synth_and_compress(
                [p.problem for p in compress_set], grammar, 
                benchmark, problem_name, k, time_out)
            synthesize_and_time(rest,
             optimiszed_grammar,
             benchmark,
             problem_name)
        end
    end
end

function synthesize_and_time(problems::Vector{<:ProblemGrammarPair},
    grammar::ContextSensitiveGrammar,
    benchmark::Module, problem_name::String)
    time_all = Millisecond(Time(now())).value
    tree_sizes, iter_counts = [], []
    for pg in problems
        problem = pg.problem
        spec = problem.spec
        gr_key = :Start # starting from "start" here because we don't need to refactor now
        solved, program, iter_count = synth_program(spec, grammar, benchmark, gr_key, problem_name)
        tree_size = if solved get_size_of_a_tree(program) else 0 end
        push!(tree_sizes, tree_size)
        push!(iter_counts, iter_count)
        println("problem: $(pg.identifier), solved: $solved, iterations: $(iter_count), tree_size: $(tree_size), program: $(program)")
    end
    println("\nTotal time (ms) $(Millisecond(Time(now())).value-time_all)")
    println("\nnum of iterations:\n$(join(iter_counts, " "))")
    println("\ntree_sizes:\n$(join(tree_sizes, " "))")
end

function baseline_run(problem_name::String)
timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    dir_path = dirname(@__FILE__)
    res_path = joinpath(dir_path, "results")
    mkpath(res_path)
    res_file_name = "Baseline_for_$(problem_name)  $(timestamp).txt"
    res_file_path = joinpath(res_path, res_file_name)

    # open results file and redirect STDIO
    open(res_file_path, "w") do io
        redirect_stdout(io) do
            println("Baseline for problem set: $(problem_name)\n")
            # get mth fraction of the problems
            benchmark = get_benchmark(problem_name)
            problem_grammar_pairs = get_all_problem_grammar_pairs(benchmark)
            grammar = problem_grammar_pairs[1].grammar
            synthesize_and_time(problem_grammar_pairs, grammar, benchmark, problem_name)
        end
    end
end


if ARGS[1] == "strings_baseline"
    baseline_run("strings")
else
    experiment_speedup_main(ARGS[0], parse(Int, ARGS[2]), parse(Int, ARGS[3]), parse(Int, ARGS[4]))
end