struct NewProgramsIterator
    level::Int
    bank::Vector{Vector{RuleNode}}
    grammar::ContextSensitiveGrammar
end

mutable struct NewProgramsState
    rule_index::Int
    sum_iter::Union{SumIterator,Nothing}
    sum_iter_state::Union{Tuple{Vector{Int},SumIteratorState},Nothing}
    cartesian_iter
    cartesian_iter_state
    index_program_option::Int
end

function Base.iterate(iter::NewProgramsIterator)
    iterate(iter, NewProgramsState(1, nothing, nothing, Iterators.product(1:1), nothing, 1))
end
function Base.iterate(iter::NewProgramsIterator, state::NewProgramsState)
    while state.rule_index <= length(iter.grammar.rules)
        if state.sum_iter === nothing
            nr_children = nchildren(iter.grammar, state.rule_index)
            rule_cost = calculate_rule_cost(state.rule_index, iter.grammar)
            if rule_cost == iter.level && nr_children == 0
                # if one rule is enough and has no children just return that tree
                program = RuleNode(state.rule_index)
                state.rule_index += 1
                state.sum_iter = nothing
                return program, state
            elseif rule_cost < iter.level && nr_children > 0
                # outer for loop not started -> start it
                state.sum_iter = SumIterator(nr_children, iter.level - rule_cost, iter.level - rule_cost)
                state.sum_iter_state = iterate(state.sum_iter)
                state.cartesian_iter = nothing
            end
        end
        # if the outerfor loop is not done
        while state.sum_iter_state !== nothing
            costs, _ = state.sum_iter_state

            # if the inner for loop is not started 
            if state.cartesian_iter === nothing
                # create inner for loop
                bank_indexed = [iter.bank[cost+1] for cost ∈ costs]
                state.cartesian_iter = Iterators.product(bank_indexed...)
                state.cartesian_iter_state = iterate(state.cartesian_iter)
            end

            if state.cartesian_iter_state === nothing
                # move one step outer for loop
                _, next_state = state.sum_iter_state
                state.sum_iter_state = iterate(state.sum_iter, next_state)
                # reset inner loop
                state.cartesian_iter = nothing
            else
                # save current values
                children, _ = state.cartesian_iter_state
                rulenode = RuleNode(state.rule_index, collect(children))
                # move to next cartesian
                _, next_state = state.cartesian_iter_state
                state.cartesian_iter_state = iterate(state.cartesian_iter, next_state)
                return rulenode, state
            end
        end
        state.rule_index += 1
        state.sum_iter = nothing
    end
    return nothing
end
