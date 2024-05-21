"""
    struct ProgramCache 

Stores the evaluation cost and the program in a structure.
This 
"""
mutable struct ProgramCache
    program::RuleNode
    correct_examples::Vector{Int}
    cost::Int
end
function Base.:(==)(a::ProgramCache, b::ProgramCache)
    return a.program == b.program
end
Base.hash(a::ProgramCache) = hash(a.program)

mutable struct ProgramCacheTrace
    program::RuleNode
    cost::Int
    reward::Float64
end

function Base.:(==)(a::ProgramCacheTrace, b::ProgramCacheTrace)
    return a.program == b.program
end
Base.hash(a::ProgramCacheTrace) = hash(a.program)

include("sum_iterator.jl")
include("new_program_iterator.jl")
include("guided_search_iterator.jl")
include("guided_trace_search_iterator.jl")

include("select_partial_sols.jl")
include("update_grammar.jl")

select_partial_solution(partial_sols::Vector{ProgramCache}, all_selected_psols::Set{ProgramCache}) = HerbSearch.selectpsol_largest_subset(partial_sols, all_selected_psols)
update_grammar!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCache}, examples::Vector{<:IOExample}) = update_grammar(grammar, PSols_with_eval_cache, examples)

"""
    probe(examples::Vector{<:IOExample}, iterator::ProgramIterator, max_time::Int, iteration_size::Int)

Probe for a solution using the given `iterator` and `examples` with a time limit of `max_time` and `iteration_size`.
"""
function probe(examples::Vector{<:IOExample}, iterator::ProgramIterator, max_time::Int, iteration_size::Int)
    start_time = time()
    # store a set of all the results of evaluation programs
    eval_cache = Set()
    state = nothing
    grammar = get_grammar(iterator.solver)
    symboltable = SymbolTable(grammar)
    # all partial solutions that were found so far
    all_selected_psols = Set{ProgramCache}()
    # start next iteration while there is time left
    while time() - start_time < max_time
        i = 1
        # partial solutions for the current synthesis cycle
        psol_with_eval_cache = Vector{ProgramCache}()
        next = state === nothing ? iterate(iterator) : iterate(iterator, state)
        while next !== nothing && i < iteration_size # run one iteration
            program, state = next

            # evaluate program
            eval_observation = []
            correct_examples = Vector{Int}()
            expr = rulenode2expr(program, grammar)
            for (example_index, example) ∈ enumerate(examples)
                output = execute_on_input(symboltable, expr, example.in)
                push!(eval_observation, output)

                if output == example.out
                    push!(correct_examples, example_index)
                end
            end

            nr_correct_examples = length(correct_examples)
            if nr_correct_examples == length(examples) # found solution
                @info "Last level: $(length(state.bank[state.level + 1])) programs"
                return program
            elseif eval_observation in eval_cache # result already in cache
                next = iterate(iterator, state)
                continue
            elseif nr_correct_examples >= 1 # partial solution 
                program_cost = calculate_program_cost(program, grammar)
                push!(psol_with_eval_cache, ProgramCache(program, correct_examples, program_cost))
            end

            push!(eval_cache, eval_observation)

            next = iterate(iterator, state)
            i += 1
        end

        # check if program iterator is exhausted
        if next === nothing
            return nothing
        end
        partial_sols = filter(x -> x ∉ all_selected_psols, select_partial_solution(psol_with_eval_cache, all_selected_psols))
        if !isempty(partial_sols)
            push!(all_selected_psols, partial_sols...)
            # update probabilites if any promising partial solutions
            update_grammar!(grammar, partial_sols, examples) # update probabilites
            # restart iterator
            eval_cache = Set()
            state = nothing

            #for loop to update all_selected_psols with new costs
            for prog_with_cache ∈ all_selected_psols
                program = prog_with_cache.program
                new_cost = calculate_program_cost(program, grammar)
                prog_with_cache.cost = new_cost
            end
        end
    end

    return nothing
end


evaluate_trace(program::RuleNode, grammar::ContextSensitiveGrammar) = error("Evaluate trace method should be overwritten")
# this is here just to be overwritten in getting_started_minerl.jl
set_env_position(x, y, z) = error("Set env position method should be overwritten")

function select_partial_solution(partial_sols::Vector{ProgramCacheTrace}, all_selected_psols::Set{ProgramCacheTrace})
    if isempty(partial_sols)
        return Vector{ProgramCache}()
    end
    push!(partial_sols, all_selected_psols...)
    # sort partial solutions by reward
    sort!(partial_sols, by=x -> x.reward, rev=true)
    to_select = 5
    return partial_sols[1 : min(to_select, length(partial_sols))]
end

"""

Probe for a solution using the given `iterator` and `examples` with a time limit of `max_time` and `iteration_size`.
"""
function probe(traces::Vector{Trace}, iterator::ProgramIterator, max_time::Int, iteration_size::Int)
    start_time = time()
    # store a set of all the results of evaluation programs
    eval_cache = Set()
    state = nothing
    grammar = get_grammar(iterator.solver)
    symboltable = SymbolTable(grammar)

    best_reward = 0
    best_eval_obs = nothing
    # all partial solutions that were found so far
    all_selected_psols = Set{ProgramCacheTrace}()
    # start next iteration while there is time left
    while time() - start_time < max_time
        i = 1
        # partial solutions for the current synthesis cycle
        psol_with_eval_cache = Vector{ProgramCacheTrace}()
        next = state === nothing ? iterate(iterator) : iterate(iterator, state)
        while next !== nothing && i < iteration_size # run one iteration
            program, state = next

            # evaluate  
            eval_observation, is_done, reward = evaluate_trace(program, grammar, show_moves = true)
            is_partial_sol = false
            if reward > best_reward 
                best_reward = reward 
                best_eval_obs = eval_observation
                printstyled("Best reward: $best_reward\n", color=:red)
                is_partial_sol = true
            end
            if is_done
                @info "Last level: $(length(state.bank[state.level + 1])) programs"
                return program
            elseif eval_observation in eval_cache # result already in cache
                next = iterate(iterator, state)
                continue
            elseif is_partial_sol # partial solution 
                cost = calculate_program_cost(program, grammar)
                push!(psol_with_eval_cache, ProgramCacheTrace(program, cost, reward))
                # if length(psol_with_eval_cache) >= 2 # play with this threshold
                #     break
                # end
            end

            push!(eval_cache, eval_observation)

            next = iterate(iterator, state)
            i += 1
        end

        # check if program iterator is exhausted
        if next === nothing
            return nothing
        end

        partial_sols = filter(x -> x ∉ all_selected_psols, select_partial_solution(psol_with_eval_cache, all_selected_psols))
        if !isempty(partial_sols)
            printstyled("Restarting!\n", color=:magenta)
            
            # set the player position to the best position so far
            set_env_position(best_eval_obs[1], best_eval_obs[2], best_eval_obs[3])

            push!(all_selected_psols, partial_sols...)
            for psol in partial_sols
                println("Partial solution: ", rulenode2expr(psol.program, grammar))
            end
            # update probabilites if any promising partial solutions
            # Idk if the update grammar call makes sense in our context now
            # update_grammar!(grammar, partial_sols) # update probabilites

            # print the grammar 
            # rule_costs = [(grammar.rules[rule_index], calculate_rule_cost(rule_index, grammar)) for rule_index in eachindex(grammar.rules)]
            # for (rule, cost) in rule_costs
            #     println("Rule: $rule : cost $cost")
            # end
            # println("====================")

            # restart iterator
            eval_cache = Set()
            state = nothing
            best_reward = 0


            #for loop to update all_selected_psols with new costs
            # for prog_with_cache ∈ all_selected_psols
            #     program = prog_with_cache.program
            #     new_cost = calculate_program_cost(program, grammar)
            #     prog_with_cache.cost = new_cost
            # end
        end
    end

    return nothing
end