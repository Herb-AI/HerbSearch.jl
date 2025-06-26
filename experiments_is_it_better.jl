using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()

using Markdown
using InteractiveUtils
using Random
using Dates
using Distributed
using Match
include("ext/RefactorExt/RefactorExt.jl")
using .RefactorExt
include("src/HerbSearch.jl")
using HerbCore, HerbGrammar, .HerbSearch, HerbSpecification, HerbBenchmarks
using Logging
include("experiments/utils.jl")
include("experiments/grammar_constraints.jl")
include("experiments/synthesize.jl")
include("experiments/heuristics.jl")
include("experiments/best_first_iterator.jl")

function experiment_speedup_main(
    problem_name::String, 
    k::Int, 
    time_out::Int # in seconds
)    
    timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
    dir_path = dirname(@__FILE__)
    res_path = joinpath(dir_path, "results")
    mkpath(res_path)
    res_file_name = "Testing_improvement_$(problem_name)_K-$(k)_t_$(time_out)_$(timestamp).txt"
    res_file_path = joinpath(res_path, res_file_name)

    # open results file and redirect STDIO
    open(res_file_path, "w") do io
        redirect_stdout(io) do
            println("Problem set: $(problem_name)\nK = $(k)\tTimeout: $(time_out)\n")
            # get mth fraction of the problems
            benchmark = get_benchmark(problem_name)
            problem_grammar_pairs = get_all_problem_grammar_pairs(benchmark)

            grammar = problem_grammar_pairs[1].grammar

            optimiszed_grammar, best_compressions = synth_and_compress(
                problem_grammar_pairs, grammar, 
                benchmark, problem_name, k, time_out)
            synthesize_and_time(problem_grammar_pairs,
             optimiszed_grammar,
             benchmark,
             problem_name, -1, best_compressions)
        end
    end
end

function synthesize_and_time(problems::Vector{<:ProblemGrammarPair},
    grammar::ContextSensitiveGrammar,
    benchmark::Module, problem_name::String,
    max_iterations,
    extra_rules = [],
)
    global_logger(SimpleLogger(stderr, Logging.Warn))
    start_time = time()
    tree_sizes, iter_counts, durations = [], [], []
    amount_solved = 0
    for pg in problems
        solved, program, cost, iter_count, t = synth_program(pg.problem.spec, grammar, benchmark, :Start, extra_rules, problem_name) 

        tree_size = if solved get_size_of_a_tree(program) else -1 end
        amount_solved = if solved amount_solved + 1 else amount_solved end
        duration = round(t, digits=2)
        push!(tree_sizes, tree_size)
        push!(iter_counts, iter_count)
        push!(durations, duration)
        println("problem: $(pg.identifier), solved: $solved, duration: $duration, iterations: $(iter_count), tree_size: $(tree_size), cost: $cost, program: $(program)")
        @warn "problem: $(pg.identifier), solved: $solved, duration: $duration, iterations: $(iter_count), tree_size: $(tree_size), cost: $cost, program: $(program)"
    end
    time_elapsed = round(time() - start_time, digits=0)
    println("\nTotal time (s) $time_elapsed")
    println("\nSolved: $amount_solved of the $(length(problems))")
    println("\ndurations:\n$(join(durations, " "))")
    println("\nnum of iterations:\n$(join(iter_counts, " "))")
    println("\ntree_sizes:\n$(join(tree_sizes, " "))")
end

function baseline_run(problem_name::String, max_iterations::Int)
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
            synthesize_and_time(problem_grammar_pairs, grammar, benchmark, problem_name, max_iterations)
        end
    end
end

# baseline_run("strings", 1)
# experiment_speedup_main("strings", parse(Int, ARGS[1]), parse(Int, ARGS[2]))

# baseline_run("bitvectors", 1)
experiment_speedup_main("bitvectors", parse(Int, ARGS[1]), parse(Int, ARGS[2]))

# if ARGS[1] == "strings_baseline"
#     baseline_run("strings", parse(Int, ARGS[2]))
# else
#     experiment_speedup_main(ARGS[1], parse(Int, ARGS[2]), parse(Int, ARGS[3]), parse(Int, ARGS[4]))
# end