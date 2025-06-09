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


function synth_program(problems::Vector,
    grammar::ContextSensitiveGrammar,
    iterator::HerbSearch.ProgramIterator,
    benchmark, name::String)
    objective_states = [problem.out for problem in problems]
    # a bitvectos have a different way of comparing results
    vecs = false
    if name == "bitvectors"
        vecs = true
    end
    count = 0
    for program ∈ iterator
        count += 1
        # there shpuld only be one value
        states = [collect(values(problem.in))[1] for problem in problems]
        grammartags = Dict{Int,Symbol}()
        if !vecs
            grammartags = benchmark.get_relevant_tags(grammar)
        end
        solved = true
        for (objective_state, state) in zip(objective_states, states)
            try
                if !vecs
                    final_state = benchmark.interpret(program, grammartags, state)
                else
                    final_state = state
                end
                if objective_state != final_state
                    solved = false
                    break
                end
            catch BoundsError
                solved = false
                break
            end           
        end
        if solved
            return solved, program, count
        end
    end
    return false, Nothing, count
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
        iterator = HerbSearch.DFSIterator(grammar, gr_key, max_depth=7) 
        program, _ = synth_program(problem, grammar, iterator, benchmark, problem_name)

        if !isnothing(program)
            push!(solutions, program)
        end
    end
    # refactor_solutions
    optimiszed_grammar = RefactorExt.HerbSearch.refactor_grammar(
        solutions, grammar, k, k*15, time_out)
    return optimiszed_grammar
end
