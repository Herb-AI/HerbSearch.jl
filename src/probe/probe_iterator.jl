include("probe_utilities.jl")

include("sum_iterator.jl")
include("new_program_iterator.jl")
include("guided_search_iterator.jl")

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
            # make sure the program is a RuleNode
            program = freeze_state(program)

            # evaluate program if it was not evaluated already
            if !isnothing(program._val)
                eval_observation, correct_examples = program._val
            else
                eval_observation, correct_examples = evaluate_program(program, grammar, examples, symboltable)
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
