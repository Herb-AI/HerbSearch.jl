@programiterator GuidedSearchTraceIterator()

function Base.iterate(iter::GuidedSearchTraceIterator)
    iterate(iter, GuidedSearchState(
        level=-1,
        bank=[],
        eval_cache=Set(),
        iter=NewProgramsIterator(0, [], get_grammar(iter.solver)),
        next_iter=nothing
    ))
end

function Base.iterate(iter::GuidedSearchTraceIterator, state::GuidedSearchState)
    grammar = get_grammar(iter.solver)
    start_symbol = get_starting_symbol(iter.solver)
    # wrap in while true to optimize for tail call
    while true
        while state.next_iter === nothing
            state.level += 1
            push!(state.bank, [])

            state.iter = NewProgramsIterator(state.level, state.bank, grammar)
            state.next_iter = iterate(state.iter)
            if state.level > 0
                @info ("Finished level $(state.level - 1) with $(length(state.bank[state.level])) programs")
                @info ("Eval_cache size : $(length(state.eval_cache)) programs")
            end
        end
        # go over all programs in a level
        while state.next_iter !== nothing
            prog::RuleNode, next_state = state.next_iter
            # move in advance
            state.next_iter = iterate(state.iter, next_state)

            # evaluate program if starting symbol
            if return_type(grammar, prog.ind) == start_symbol
                eval_observation, is_done, final_reward = evaluate_trace(prog, grammar)
                eval_observation_rounded = round.(eval_observation, digits=1)
                if eval_observation_rounded in state.eval_cache # program already cached
                    continue
                end

                push!(state.eval_cache, eval_observation_rounded) # add result to cache
                push!(state.bank[state.level+1], prog) # add program to bank

                return ((prog, (eval_observation, is_done, final_reward)), state) # return program
            end

            push!(state.bank[state.level+1], prog) # add program to bank
        end
    end
end
