Base.@doc """
    NewProgramsIterator(level::Int,bank::Vector{Vector{RuleNode}}, grammar::ContextSensitiveGrammar)

The `NewProgramsIterator` is an iterator that corresponds to the `NewPrograms` from the Algorithm 1 pseudocode from the Probe Paper 
(Just-in-Time Learning for Bottom-Up Enumerative Synthesis: https://arxiv.org/abs/2010.08663)
The pseudocode is shown below.

```
Input: PCFG G𝑝 , cost level Lvl, program bank B filled up to Lvl - 1
Output: Iterator over all programs of cost Lvl

16: procedure New-Programs(G𝑝 , Lvl, B)
17:   for (R = N → (𝑡 N1 N2 . . . N𝑘 ) ∈ R) do       ⊲ For all production rules
18:      if cost(R) = Lvl ∧ 𝑘 = 0 then                    ⊲ t has arity zero
19:        yield 𝑡
20:      else if cost(R) < Lvl ∧ 𝑘 > 0 then               ⊲ t has non-zero arity
21:        for (c1, ..., ck) ∈ [1, Lvl] such that Σci = Lvl - cost(R) do   ⊲ For all subexpression costs
22:           for (P1, ..., Pk) ∈ { B[c1] × ... × B[ck] | Ni ⇒* Pi }  do  ⊲ For all subexpressions
23:              yield (t P1 ... Pk)
```

The NewProgramsIterator implements the _yielding_ by manually storing the indices of each for loop as the state of the iterator.
""" NewProgramsIterator

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

function calculate_rule_cost_prob(rule_index::Int, grammar::ContextSensitiveGrammar, log_base = 2)
    log_prob = grammar.log_probabilities[rule_index] / log(log_base)
    return convert(Int64, round(-log_prob))
end

function calculate_rule_cost_size(rule_index, grammar)
    return 1
end

calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = calculate_rule_cost_size(rule_index, grammar)

"""
    calculate_program_cost(program::RuleNode, grammar::ContextSensitiveGrammar)  
Calculates the cost of a program by summing up the cost of the children and the cost of the rule
"""
function calculate_program_cost(program::RuleNode, grammar::ContextSensitiveGrammar)
    cost_children = sum([calculate_program_cost(child, grammar) for child ∈ program.children], init=0)
    cost_rule = calculate_rule_cost(program.ind, grammar)
    return cost_children + cost_rule
end