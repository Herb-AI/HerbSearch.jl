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
    res_file_name = "P_$(problem_name)_Frac_$(using_mth)_K-$(k)_t_$(time_out)_$(timestamp).txt"
    res_file_path = joinpath(res_path, res_file_name)

    # open results file and redirect STDIO
    open(res_file_path, "w") do io
        redirect_stdout(io) do
            println("Problem set: $(problem_name)\nUsing $(using_mth) fraction\nK = $(k)\tTimeout: $(time_out)\n")
            # get mth fraction of the problems
            benchmark = get_benchmark(problem_name)
            problem_grammar_pairs = get_all_problem_grammar_pairs(benchmark)
            shuffle!(rng, problem_grammar_pairs)
            grammar = problem_grammar_pairs[1].grammar
            problems, _ = take_mth_fraction(problem_grammar_pairs, 5, using_mth)
            solutions = Vector{RuleNode}([])
            # solve prolems
            for (_, pg) in enumerate(problems)
                problem = pg.problem.spec
                if problem_name == "bitvectors"
                    gr_key = :Start
                else
                    gr_key = :Sequence
                end
                iterator = HerbSearch.DFSIterator(grammar, gr_key, max_depth=7) 
                program, _ = synth_program(problem, grammar, iterator, benchmark, problem_name)

                if !isnothing(program)
                    push!(solutions, program)
                end
            end
            # refactor_solutions
            optimiszed_grammar = RefactorExt.HerbSearch.refactor_grammar(
                solutions, grammar, k, k*15, time_out)
            println("\nGrammar:\n$(optimiszed_grammar)")
        end
    end
end

# println("strings")
# experiments_main("strings", 1, 3, 10)
# println("robots")
# experiments_main("robots", 1, 3, 10)
# println("pixels")
# experiments_main("pixels", 1, 3, 10)

experiments_main(ARGS[1], parse(Int, ARGS[2]), parse(Int, ARGS[3]), parse(Int, ARGS[4]))