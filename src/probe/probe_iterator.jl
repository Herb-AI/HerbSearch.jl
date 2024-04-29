@programiterator ProbeSearchIterator(
    spec::Vector{<:IOExample},
    cost_function::Function,
    level_limit = 8
) 

@kwdef mutable struct ProbeSearchState 
    level::Int64
    bank::Vector{Vector{RuleNode}}
    eval_cache::Set
    partial_sols::Vector{RuleNode} 
end

function calculate_rule_cost_prob(rule_index, grammar)
    log_prob = grammar.log_probabilities[rule_index]
    return convert(Int64,round(-log_prob))
end

function calculate_rule_cost_size(rule_index, grammar)
    return 1
end

# TODO: Have a nice way to switch from cost_size to cost_prob using multiple dispath maybe
calculate_rule_cost(rule_index, grammar::ContextSensitiveGrammar) = calculate_rule_cost_size(rule_index, grammar)

# generate in terms of increasing height
function newprograms(grammar, level, bank, start_time)
    arr = []
    # TODO: Use a generator instead of using arr and pushing values to it
    for rule_index ∈ 1:length(grammar.rules)
        nr_children = nchildren(grammar, rule_index)
        rule_cost = calculate_rule_cost(rule_index, grammar)
        if rule_cost == level && nr_children == 0
            # if one rule is enough and has no children just return that tree
            push!(arr, RuleNode(rule_index))
        elseif rule_cost < level && nr_children > 0
            # find all costs that sum up to level  - rule_cost
            # an  efficient version using for loops 
            # for i in 1:level 
            #     for j in i:level 
            #         for k in j:level 
            #             # ... have `nr_childre` number of nested for loops
            # create a list of nr_children iterators 
            iterators = []
            for i ∈ 1:nr_children
                push!(iterators, 1:(level - rule_cost))
            end
            options = Iterators.product(iterators...)
            # TODO : optimize options generation 
            for costs ∈ options
                if sum(costs) == level - rule_cost
                    # julia indexes from 1 that is why I add 1 here
                    bank_indexed = [bank[cost + 1] for cost ∈ costs]
                    cartensian_product = Iterators.product(bank_indexed...)
                    for program_options ∈ cartensian_product
                        # TODO: check if the right types are good 
                        # [program_options...] is just to convert from tuple to array
                        rulenode = RuleNode(rule_index, [program_options...])
                        push!(arr, rulenode)
                        if time() - start_time >= 10
                            @warn "Probe took more than 10 seconds to run..."
                            return arr
                        end
                    end
                end
            end
        end
    end
    return arr
end

function Base.iterate(iter::ProbeSearchIterator)
    iterate(iter, ProbeSearchState(
        level = 0,
        bank = Vector(),
        eval_cache = Set(), 
        partial_sols = Vector() 
        )
    )
end

function Base.iterate(iter::ProbeSearchIterator, state::ProbeSearchState)
    # mutate state in place
    start_level = state.level
    start_time = time()
    while state.level <= start_level + iter.level_limit
        # add another level to the bank that is empty
        push!(state.bank,[])
        new_programs = newprograms(iter.grammar, state.level, state.bank, start_time)
        if time() - start_time >= 10
            @warn "Probe took more than 10 seconds to run..."
            return (nothing, state)
        end
        for program ∈ new_programs
            # a list with all the outputs
            eval_observation = []
            nr_correct_examples = 0
            for example ∈ iter.spec
                output = execute_on_input(iter.grammar, program, example.in)
                push!(eval_observation, output)

                if output == example.out
                    nr_correct_examples += 1
                end
            end
            if nr_correct_examples == length(iter.spec)
                # done
                return (program, state)
            elseif eval_observation in state.eval_cache
                continue
            elseif nr_correct_examples >= 1
                push!(state.partial_sols, program)
            end
            push!(state.bank[state.level + 1], program)
            push!(state.eval_cache,  eval_observation)
        end
        state.level = state.level + 1
    end
    return (nothing, state)
end

