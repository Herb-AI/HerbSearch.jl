using Markdown
using InteractiveUtils
using Random
using Dates
include("RefactorExt.jl")
using .RefactorExt
include("../../src/HerbSearch.jl")
using HerbCore, HerbGrammar, .HerbSearch, HerbSpecification, HerbBenchmarks

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
    res_file_name = "P_$(problem_name)_Frac_$(using_mth)_K-$(k)__$(timestamp).txt"
    res_file_path = joinpath(res_path, res_file_name)

    # open results file and redirect STDIO
    open(res_file_path, "w") do io
        redirect_stdout(io) do
            println("Problem set: $(problem_name)\nUsing $(using_mth) fraction\nK = $(k)\tTimeout: $(time_out)\n")
            # get mth fraction of the problems
            benchmark = get_benchmark(problem_name)
            problem_grammar_pairs = get_all_problem_grammar_pairs(benchmark)
            shuffle!(problem_grammar_pairs, rng)
            grammar = problem_grammar_pairs[1].grammar
            problems = take_mth_fraction(problem_grammar_pairs, 5, using_mth)
            solutions = Vector{RuleNode}([])
            # solve prolems
            for (_, pg) in enumerate(problems)
                problem = pg.problem.spec
                if problem_name == "bitvector"
                    gr_key = :Start
                else
                    gr_key = :Sequence
                end
                iterator = HerbSearch.DFSIterator(grammar, gr_key, max_depth=7) 
                program = synth_program(problem, grammar, iterator, benchmark)

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

function take_mth_fraction(list::AbstractVector, N::Int, m::Int)
    len = length(list)
    part_size = ceil(Int, len / N)
    start_idx = (m - 1) * part_size + 1
    end_idx = min(m * part_size, len)
    return list[start_idx:end_idx]
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


function synth_program(problems::Vector,
    grammar::ContextSensitiveGrammar,
    iterator::HerbSearch.ProgramIterator,
    benchmark)
    objective_states = [problem.out for problem in problems]
    for program ∈ iterator
        # there shpuld only be one value
        states = [collect(values(problem.in))[1] for problem in problems]
        grammartags =  benchmark.get_relevant_tags(grammar)
        
        solved = true
        for (objective_state, state) in zip(objective_states, states)
            try
                final_state = benchmark.interpret(program, grammartags, state)
                
                if objective_state != final_state
                    solved = false
                    break
                end
            catch BoundsError
                break
            end           
        end
        if solved
            return program
        end
    end
end

# println("strings")
# experiments_main("strings", 1, 3, 10)
# println("robots")
# experiments_main("robots", 1, 3, 10)
println("bitvectors")
experiments_main("bitvectors", 1, 3, 10)