# abstract type AbstractBestFirstIterator <: HerbSearch.TopDownIterator end
# @HerbSearch.programiterator BestFirstIterator() <: AbstractBestFirstIterator

global program_distances = nothing
global current_states = nothing
global current_objective_states = nothing
global current_benchmark = nothing
global current_benchmark_name = nothing

function HerbSearch.priority_function(
    ::HerbSearch.BFSIterator,
    grammar::AbstractGrammar, 
    current_program::AbstractRuleNode, 
    parent_value::Union{Real, Tuple{Vararg{Real}}},
    isrequeued::Bool
)
    try
        distance = get_distance(current_states, current_objective_states, current_benchmark, current_benchmark_name, grammar, current_program)
        program_distances[hash(current_program)] = distance
        return distance
    catch e
        if isa(e, AssertionError)
            return 0.1
        else
            rethrow(e)
        end
    end
end



function synth_program(problems::Vector, grammar::ContextSensitiveGrammar, benchmark, gr_key, name::String)
    iterator = HerbSearch.BFSIterator(grammar, gr_key, max_depth=8) 
    objective_states = [problem.out for problem in problems]

    global program_distances = Dict()
    global current_states = [collect(values(problem.in))[1] for problem in problems]
    global current_objective_states = objective_states
    global current_benchmark = benchmark
    global current_benchmark_name = name

    count = 0

    for program ∈ iterator
        count += 1

        distance = program_distances[hash(program)]
        delete!(program_distances, hash(program))
        
        if distance == 0
            return true, program, count
        end

        if count == 100000
            break
        end
    end
    return false, Nothing, count
end

function get_distance(states, objective_states, benchmark, name, grammar, program)
    grammartags = Dict{Int,Symbol}()
    if name != "bitvectors"
        grammartags = benchmark.get_relevant_tags(grammar)
    end
    
    distance = 0

    for (objective_state, state) in zip(objective_states, states)
        try
            if name != "bitvectors"
                final_state = benchmark.interpret(program, grammartags, state)
            else
                final_state = state
            end
            
            if name == "strings"
                del_cost = 1
                insr_cost = 1
                subst_cost = 1
                distance += levenshtein!(final_state.str, objective_state.str, del_cost, insr_cost, subst_cost)
            end

        catch e
            if isa(e, BoundsError)
                return Inf
            else
                rethrow(e)
            end
        end           
    end

    return distance
end