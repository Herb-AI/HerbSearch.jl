function take_mth_fraction(list::AbstractVector, N::Int, m::Int)
    len = length(list)
    part_size = ceil(Int, len / N)
    start_idx = (m - 1) * part_size + 1
    end_idx = min(m * part_size, len)
    return list[start_idx:end_idx], [list[1:start_idx-1]; list[end_idx+1:len]] 
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

"""
problems - vector of differnet types of programs
for each type, split them into sets of 20/80% and return them as vector
"""
function split_problems(problems::Vector{ProblemGrammarPair}, m::Int)
    compression_set = []
    rest_set = []
    for pair in problems
        problem = pair.problem
        spec = problem.spec
        ts, rs = take_mth_fraction(spec, 5, m)
        test_problem = Problem(ts)
        rest_problem = Problem(rs)
        push!(compression_set, test_problem)
        push!(rest_set, rest_problem)
    end
    # both are vectors of problems
    return compression_set, rest_set 
end

function get_size_of_a_tree(rule::RuleNode)
    res = 1
    for c in rule.children
        if typeof(c) == RuleNode 
            res += get_size_of_a_tree(c)
        else
            # this is a terminal I guess
            res += 1
        end
    end
    return res
end

function synth_and_compress(compress_set::Vector{<:Problem},
    grammar::AbstractGrammar,
    benchmark::Module,
    problem_name::String,
    k::Int64, 
    time_out::Int64)
    solutions = Vector{RuleNode}([])
    for p in compress_set
        problem = p.spec
        if problem_name == "bitvectors"
            gr_key = :Start
        else
            gr_key = :Sequence
        end
        program, _ = synth_program(problem, grammar, benchmark, problem_name)

        if !isnothing(program)
            push!(solutions, program)
        end
    end
    # refactor_solutions
    optimiszed_grammar = RefactorExt.HerbSearch.refactor_grammar(
        solutions, grammar, k, k*15, time_out)
    return optimiszed_grammar
end
