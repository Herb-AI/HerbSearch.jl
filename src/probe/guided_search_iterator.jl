Base.@doc """
    GuidedSearchIterator(spec::Vector{<:IOExample}, symboltable::SymbolTable)

GuidedSearchIteartor is a bottom-up iterator that iterates programs in order of decreasing probabilities.
This algorithm was taken from the Probe paper (Just-in-time learning for bottom-up enumerative synthesis: https://arxiv.org/abs/2010.08663).

It generates programs level-by-level where the level means a given probability. To generate programs it looks at programs generated for previous levels by using 
dynamic-programming. All generated programs are stored in the `bank`. For each level the bank stores the program corresponding to that level.

This algorithm employs a powerful pruning technique called: Overvational Equivalence. This means that if two progams produce the same output on all examples they 
are considered to be equivalent and only one of them is stored in the bank.
This iterator uses the [`NewProgramsIterator`]@ref behind the scenes.
""" GuidedSearchIterator

@programiterator GuidedSearchIterator(
    spec::Vector{<:IOExample},
    symboltable::SymbolTable,
)
Base.@kwdef mutable struct GuidedSearchState
    level::Int64
    bank::Vector{Vector{RuleNode}}
    eval_cache::Set
    iter::NewProgramsIterator
    next_iter::Union{Tuple{RuleNode, NewProgramsState}, Nothing}
end

function Base.iterate(iter::GuidedSearchIterator)
    iterate(iter, GuidedSearchState(
        level=-1,
        bank=[],
        eval_cache=Set(),
        iter=NewProgramsIterator(0, [], get_grammar(iter.solver)),
        next_iter=nothing
    ))
end

function Base.iterate(iter::GuidedSearchIterator, state::GuidedSearchState)::Union{Tuple{RuleNode, GuidedSearchState}, Nothing}
    grammar = get_grammar(iter.solver)
    start_symbol = get_starting_symbol(iter.solver)
    # wrap in while true to optimize for tail call
    max_time = 10 
    start_time = time()
    while true
        while state.next_iter === nothing
            if time() - start_time > max_time
                return nothing
            end

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
            if time() - start_time > max_time
                return nothing
            end


            # prog = pop!(state.programs) # get next program
            prog::RuleNode, next_state = state.next_iter
            # move in advance
            state.next_iter = iterate(state.iter, next_state)

            # evaluate program if starting symbol
            if return_type(grammar, prog.ind) == start_symbol
                eval_observation, correct_examples = evaluate_program(prog, grammar, iter.spec, iter.symboltable)

                if eval_observation in state.eval_cache # program already cached
                    continue
                end
                prog._val = (eval_observation, correct_examples)
                
                push!(state.eval_cache, eval_observation) # add result to cache
                push!(state.bank[state.level+1], prog) # add program to bank
                return (prog, state) # return program
            end

            push!(state.bank[state.level+1], prog) # add program to bank
        end
    end
end
