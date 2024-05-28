"""
    get_prog_eval(iterator, prog)

Get the program and its evaluation.
"""
get_prog_eval(::ProgramIterator, prog::RuleNode) = (prog, [])

get_prog_eval(::GuidedSearchIterator, prog::Tuple{RuleNode,Vector{Any}}) = prog

get_prog_eval(::GuidedSearchTraceIterator, prog::Tuple{RuleNode,Tuple{Any,Bool,Number}}) = prog

"""
    probe(examples::Vector{<:IOExample}, iterator::ProgramIterator, max_time::Int, cycle_length::Int)

Probe for a solution using the given `iterator` and `examples` with a time limit of `max_time` and a cycle length of `cycle_length`.

The selection, update, and cost functions can be changed by overriding the following functions:
- [`select_partial_solution`](@ref)
- [`update_grammar!`](@ref)
- [`calculate_rule_cost`](@ref)
"""
function probe(examples::Vector{<:IOExample}, iterator::ProgramIterator; max_time::Int, cycle_length::Int)
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
        while next !== nothing && i < cycle_length # run one cycle
            program, state = next

            # evaluate program
            program, eval_observation = get_prog_eval(iterator, program)
            correct_examples = Vector{Int}()
            if isempty(eval_observation)
                expr = rulenode2expr(program, grammar)
                for (example_index, example) ∈ enumerate(examples)
                    output = execute_on_input(symboltable, expr, example.in)
                    push!(eval_observation, output)

                    if output == example.out
                        push!(correct_examples, example_index)
                    end
                end
            else
                for i in 1:length(eval_observation)
                    if eval_observation[i] == examples[i].out
                        push!(correct_examples, i)
                    end
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

"""
    evaluate_trace(program::RuleNode, grammar::ContextSensitiveGrammar)

Evaluate the `program` with the `grammar`.
"""
evaluate_trace(program::RuleNode, grammar::ContextSensitiveGrammar; show_moves::Bool) = error("Evaluate trace method should be overwritten")

function probe(traces::Vector{Trace}, iterator::ProgramIterator; max_time::Int, cycle_length::Int)
    start_time = time()
    # store a set of all the results of evaluation programs
    eval_cache = Set()
    state = nothing
    grammar = get_grammar(iterator.solver)

    best_reward = 0
    # all partial solutions that were found so far
    all_selected_psols = Set{ProgramCacheTrace}()
    # start next iteration while there is time left
    while time() - start_time < max_time
        i = 1
        # partial solutions for the current synthesis cycle
        psol_with_eval_cache = Vector{ProgramCacheTrace}()
        next = state === nothing ? iterate(iterator) : iterate(iterator, state)
        while next !== nothing && i < cycle_length # run one cycle
            program, state = next

            # evaluate
            program, evaluation = get_prog_eval(iterator, program)
            eval_observation, is_done, reward = isempty(evaluation) ? evaluate_trace(program, grammar, show_moves=true) : evaluation
            eval_observation_rounded = round.(eval_observation, digits=1)
            is_partial_sol = false
            if reward > best_reward + 0.2
                best_reward = reward
                printstyled("Best reward: $best_reward\n", color=:red)
                is_partial_sol = true
            end
            if is_done
                @info "Last level: $(length(state.bank[state.level + 1])) programs"
                return program
            elseif eval_observation_rounded in eval_cache # result already in cache
                next = iterate(iterator, state)
                continue
            elseif is_partial_sol # partial solution 
                cost = calculate_program_cost(program, grammar)
                push!(psol_with_eval_cache, ProgramCacheTrace(program, cost, reward))
            end

            push!(eval_cache, eval_observation_rounded)

            i += 1
            if i < cycle_length
                next = iterate(iterator, state)
            end
        end

        # check if program iterator is exhausted
        if next === nothing
            return nothing
        end

        partial_sols = filter(x -> x ∉ all_selected_psols, select_partial_solution(psol_with_eval_cache, all_selected_psols))
        if !isempty(partial_sols)
            printstyled("Restarting!\n", color=:magenta)

            update_grammar!(grammar, partial_sols) # update probabilites

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