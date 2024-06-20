calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = calculate_rule_cost_prob(rule_index, grammar)

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

                # filter out wrong types
                types = child_types(iter.grammar, state.rule_index)
                for i in 1:length(types)
                    bank_indexed[i] = filter(x -> return_type(iter.grammar, x.ind) == types[i], bank_indexed[i])
                end

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

"""
    calculate_rule_cost_prob(rule_index::Int, grammar::ContextSensitiveGrammar)

Calculate cost of rule `rule_index` in `grammar` based on its probability.

``cost = -log_{base}(probability)``
"""
function calculate_rule_cost_prob(rule_index::Int, grammar::ContextSensitiveGrammar)
    log_prob = grammar.log_probabilities[rule_index]
    return convert(Int64, round(-log_prob))
end

"""
    calculate_rule_cost_size(::Int, ::ContextSensitiveGrammar)

Calculate rule cost based on size.

This will always return 1.
"""
function calculate_rule_cost_size(::Int, ::ContextSensitiveGrammar)
    return 1
end

"""
    calculate_program_cost(program::RuleNode, grammar::ContextSensitiveGrammar)

Calculates the cost of a program by summing up the cost of the children and the cost of the rule.
"""
function calculate_program_cost(program::RuleNode, grammar::ContextSensitiveGrammar)
    cost_children = sum([calculate_program_cost(child, grammar) for child ∈ program.children], init=0)
    cost_rule = calculate_rule_cost(program.ind, grammar)
    return cost_children + cost_rule
end