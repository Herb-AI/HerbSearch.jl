
@programiterator GuidedSearchIterator(
    spec::Vector{<:IOExample},
    symboltable::SymbolTable,
    start::Symbol
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
            # prog = pop!(state.programs) # get next program
            prog::RuleNode, next_state = state.next_iter
            # move in advance
            state.next_iter = iterate(state.iter, next_state)

            # evaluate program if starting symbol
            if return_type(grammar, prog.ind) == iter.start
                eval_observation = []
                expr = rulenode2expr(prog, grammar)
                for example ∈ iter.spec
                    output = execute_on_input(iter.symboltable, expr, example.in)
                    push!(eval_observation, output)
                end

                if eval_observation in state.eval_cache # program already cached
                    continue
                end
                
                push!(state.eval_cache, eval_observation) # add result to cache
                push!(state.bank[state.level+1], prog) # add program to bank
                return (prog, state) # return program
            end

            push!(state.bank[state.level+1], prog) # add program to bank
        end
    end
end