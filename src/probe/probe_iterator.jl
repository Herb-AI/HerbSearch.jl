"""
    struct ProgramCache 

Stores the evaluation cost and the program in a structure.
This 
"""
struct ProgramCache
    program::RuleNode 
    correct_examples::Vector{Int}
    cost::Int
end

function probe(examples::Vector{<:IOExample}, iterator::ProgramIterator, select::Function, update!::Function, max_time::Int, iteration_size::Int)
    start_time = time()
    # store a set of all the results of evaluation programs
    eval_cache = Set()
    state = nothing
    symboltable = SymbolTable(iterator.grammar)
    # all partial solutions that were found so far
    all_selected_psols  = Set{RuleNode}()
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
            expr = rulenode2expr(program, iterator.grammar)
            for (example_index, example) ∈ enumerate(examples)
                output = execute_on_input(symboltable, expr, example.in)
                push!(eval_observation, output)
                
                if output == example.out
                    push!(correct_examples, example_index)
                end
            end

            nr_correct_examples = length(correct_examples)
            if nr_correct_examples == length(examples) # found solution
                println("Last level: $(length(state.bank[state.level + 1])) programs")
                return program
            elseif eval_observation in eval_cache # result already in cache
                next = iterate(iterator, state)
                continue
            elseif nr_correct_examples >= 1 # partial solution 
                program_cost = calculate_program_cost(program, iterator.grammar)
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
        # select promising partial solutions that did not appear before              
        partial_sols = filter(x -> x.program ∉ all_selected_psols, select(psol_with_eval_cache))
        if !isempty(partial_sols)
            push!(all_selected_psols, map(x -> x.program, partial_sols)...)
        end
        # # update probabilites if any promising partial solutions
        # if !isempty(partial_sols)
        #     update!(iterator.grammar, partial_sols, eval_cache) # update probabilites
        #     # restart iterator
        #     eval_cache = Set() 
        #     state = nothing
        # end
    end

    return nothing
end

"""
    selectpsol_largest_subset(partial_sols::Vector{ProgramCache}) 

This scheme selects a single cheapest program (first enumerated) that 
satisfies the largest subset of examples encountered so far across all partial_sols.
"""
function selectpsol_largest_subset(partial_sols::Vector{ProgramCache})
    if isempty(partial_sols)
        return Vector{ProgramCache}() 
    end
    largest_subset_length = 0
    cost = typemax(Int)
    best_sol = partial_sols[begin]
    for psol in partial_sols
        len = length(psol.correct_examples)
        if len > largest_subset_length || len == largest_subset_length && psol.cost < cost
            largest_subset_length = len
            best_sol = psol
            cost = psol.cost
        end
    end
    return [best_sol]
end

"""
    selectpsol_first_cheapest(partial_sols::Vector{ProgramCache}) 

This scheme selects a single cheapest program (first enumerated) that 
satisfies a unique subset of examples.
"""
function selectpsol_first_cheapest(partial_sols::Vector{ProgramCache})  
    # maps subset of examples to the cheapest program 
    mapping = Dict{Vector{Int}, ProgramCache}()
    for sol ∈ partial_sols
        examples = sol.correct_examples
        if !haskey(mapping, examples)
            mapping[examples] = sol
        else
            # if the cost of the new program is less than the cost of the previous program with the same subset of examples replace it
            if sol.cost < mapping[examples].cost
                mapping[examples] = sol
            end
        end
    end
    # get the cheapest programs that satisfy unique subsets of examples
    return values(mapping)
end

"""
    selectpsol_all_cheapest(partial_sols::Vector{ProgramCache}) 

This scheme selects all cheapest programs that satisfies a unique subset of examples.
"""
function selectpsol_all_cheapest(partial_sols::Vector{ProgramCache})  
    # maps subset of examples to the cheapest program 
    mapping = Dict{Vector{Int}, Vector{ProgramCache}}()
    for sol ∈ partial_sols
        examples = sol.correct_examples
        if !haskey(mapping, examples)
            mapping[examples] = [sol]
        else
            # if the cost of the new program is less than the cost of the first program
            progs = mapping[examples]
            if sol.cost < progs[begin].cost
                mapping[examples] = [sol]
            elseif sol.cost == progs[begin].cost
                # append to the list of cheapest programs
                push!(progs, sol)
            end
        end
    end
    # get all cheapest programs that satisfy unique subsets of examples
    return Iterators.flatten(values(mapping))
end

@programiterator GuidedSearchIterator(
    spec::Vector{<:IOExample},
    symboltable::SymbolTable
)
@kwdef mutable struct GuidedSearchState 
    level::Int64
    bank::Vector{Vector{RuleNode}}
    eval_cache::Set
    programs::Vector{RuleNode}
end
function Base.iterate(iter::GuidedSearchIterator)
    iterate(iter, GuidedSearchState(
        level = -1,
        bank = [],
        eval_cache = Set(),
        programs = []
    ))
end

function Base.iterate(iter::GuidedSearchIterator, state::GuidedSearchState)
    # increment level while programs is empty
    while isempty(state.programs)
        state.level += 1
        push!(state.bank, [])
        state.programs = newprograms(iter.grammar, state.level, state.bank)
        if state.level > 0
            println("Finished level $(state.level - 1) with $(length(state.bank[state.level])) programs")
        end
    end

    # go over all programs in a level
    while !isempty(state.programs)
        prog = pop!(state.programs) # get next program

        # evaluate program
        eval_observation = []
        expr = rulenode2expr(prog, iter.grammar)
        for example ∈ iter.spec
            output = execute_on_input(iter.symboltable, expr, example.in)
            push!(eval_observation, output)
        end
        
        if eval_observation in state.eval_cache # program already cached
            continue
        end

        push!(state.bank[state.level + 1], prog) # add program to bank
        push!(state.eval_cache, eval_observation) # add result to cache
        return(prog, state) # return program
    end
    
    # current level has been exhausted, go to next level
    return iterate(iter, state)
end

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
"""
struct SumIterator

This struct is used to generate all possible combinations of `number_of_elements` numbers that sum up to `desired_sum`.
The number will be in range `1:max_value` inclusive.

!!! warning 
    This iterator mutates the state in place. Deepcopying the state for each iteartion is needed to have an overview of all the possible combinations.

# Example 
```julia
sum_iter = HerbSearch.SumIterator(number_of_elements=4, desired_sum=5, max_value=2)
options = Vector{Vector{Int}}()
for option ∈ sum_iter
    # deep copy is needed because the iterator mutates the state in place
    push!(options, deepcopy(option))
end
```
"""
@kwdef struct SumIterator
    number_of_elements::Int 
    desired_sum::Int
    max_value::Int
end
mutable struct SumIteratorState
    current_sum::Int
    current_elements::Vector{Int}
    current_index::Int
end

function Base.iterate(iter::SumIterator)
    array::Vector{Int} = fill(0, iter.number_of_elements) 
    iterate(iter, SumIteratorState(0, array, 1))
end

function Base.iterate(iter::SumIterator, state::SumIteratorState)
    @assert state.current_sum == sum(state.current_elements)
    while state.current_index >= 1
        sum_left = iter.desired_sum - state.current_sum
        starting = state.current_elements[state.current_index] + 1
        # println("Starting: $starting | min(sum_left,iter.max_value) :$(min(sum_left, iter.max_value))")
        for i ∈ starting : min(starting + sum_left - 1, iter.max_value)
            state.current_sum += 1 # increase sum by 1
            state.current_elements[state.current_index] = i
            # check if we have one more element to put 
            if state.current_index == iter.number_of_elements 
                # we have the correct sum
                if state.current_sum == iter.desired_sum
                    return state.current_elements, state
                end
            else
                state.current_index += 1
                return iterate(iter, state)
            end
        end
        state.current_sum -= state.current_elements[state.current_index]
        state.current_elements[state.current_index] = 0
        state.current_index -= 1
    end
    return nothing
end


new_programs(grammar,level,bank) = newprograms_efficient
# generate in terms of increasing height
function newprograms_old(grammar, level, bank)
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

            for costs ∈ options
                if sum(costs) == level - rule_cost
                    # julia indexes from 1 that is why I add 1 here
                    bank_indexed = [bank[cost + 1] for cost ∈ costs]
                    cartesian_product = Iterators.product(bank_indexed...)
                    for program_options ∈ cartesian_product
                        # TODO: check if the right types are good 
                        # [program_options...] is just to convert from tuple to array
                        rulenode = RuleNode(rule_index, [program_options...])
                        push!(arr, rulenode)
                    end
                end
            end
        end
    end

    return arr
end

function newprograms_efficient(grammar, level, bank)
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
            iterator = SumIterator(number_of_elements=nr_children, desired_sum = level - rule_cost, max_value = level - rule_cost)
            # TODO : optimize options generation 
            for costs ∈ iterator
                @assert sum(costs) + rule_cost == level
                # julia indexes from 1 that is why I add 1 here
                bank_indexed = [bank[cost + 1] for cost ∈ costs]
                cartesian_product = Iterators.product(bank_indexed...)
                for program_options ∈ cartesian_product
                    # TODO: check if the right types are good 
                    # [program_options...] is just to convert from tuple to array
                    rulenode = RuleNode(rule_index, [program_options...])
                    push!(arr, rulenode)
                end
            end 
        end
    end

    return arr
end