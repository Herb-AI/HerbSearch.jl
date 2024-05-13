include("sum_iterator.jl")
include("new_program_iterator.jl")
include("guided_search_iterator.jl")
"""
    struct ProgramCache 

Stores the evaluation cost and the program in a structure.
This 
"""
mutable struct ProgramCache
    program::RuleNode
    correct_examples::Vector{Int}
    cost::Int
end
function Base.:(==)(a::ProgramCache, b::ProgramCache)
    return a.program == b.program
end
Base.hash(a::ProgramCache) = hash(a.program)

select(partial_sols::Vector{ProgramCache}, all_selected_psols::Set{ProgramCache}) = HerbSearch.selectpsol_largest_subset(partial_sols, all_selected_psols)
update!(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCache}, examples::Vector{<:IOExample}) = update_grammar(grammar, PSols_with_eval_cache, examples)

function probe(examples::Vector{<:IOExample}, iterator::ProgramIterator, max_time::Int, iteration_size::Int)
    start_time = time()
    # store a set of all the results of evaluation programs
    eval_cache = Set()
    state = nothing
    symboltable = SymbolTable(iterator.grammar)
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
        partial_sols = filter(x -> x ∉ all_selected_psols, select(psol_with_eval_cache, all_selected_psols))
        if !isempty(partial_sols)
            print(rulenode2expr(partial_sols[1].program, iterator.grammar))
            push!(all_selected_psols, partial_sols...)
            # update probabilites if any promising partial solutions
            update!(iterator.grammar, partial_sols, examples) # update probabilites
            # restart iterator
            eval_cache = Set()
            state = nothing

            #for loop to update all_selected_psols with new costs
            for prog_with_cache ∈ all_selected_psols
                program = prog_with_cache.program
                new_cost = calculate_program_cost(program, iterator.grammar)
                prog_with_cache.cost = new_cost
            end
        end
    end

    return nothing
end

function update_grammar(grammar::ContextSensitiveGrammar, PSols_with_eval_cache::Vector{ProgramCache}, examples::Vector{<:IOExample})
    sum = 0
    for rule_index in eachindex(grammar.rules) # iterate for each rule_index 
        highest_correct_nr = 0
        for psol in PSols_with_eval_cache
            program = psol.program
            len_correct_examples = length(psol.correct_examples)
            # check if the program tree has rule_index somewhere inside it using a recursive function
            if contains_rule(program, rule_index) && len_correct_examples > highest_correct_nr
                highest_correct_nr = len_correct_examples
            end
        end
        fitnes = highest_correct_nr / length(examples)
        p_uniform = 1 / length(grammar.rules)

        # compute (log2(p_u) ^ (1 - fit)) = (1-fit) * log2(p_u)
        sum += p_uniform^(1 - fitnes)
        log_prob = ((1 - fitnes) * log(2, p_uniform))
        grammar.log_probabilities[rule_index] = log_prob
    end
    total_sum = 0
    for rule_index in eachindex(grammar.rules)
        grammar.log_probabilities[rule_index] = grammar.log_probabilities[rule_index] - log(2, sum)
        total_sum += 2^(grammar.log_probabilities[rule_index])
    end
    @assert abs(total_sum - 1) <= 1e-4 "Total sum is $(total_sum) "
end

"""
    contains_rule(program::RuleNode, rule_index::Int)

Check if a given `RuleNode` contains has used a derivation rule with the specified `rule_index`

# Arguments
- `program::RuleNode`: The `RuleNode` to check.
- `rule_index::Int`: The index of the rule to check for.

"""
function contains_rule(program::RuleNode, rule_index::Int)
    if program.ind == rule_index # if the rule is good return true
        return true
    else
        for child in program.children
            if contains_rule(child, rule_index)  # if a child has that rule then return true
                return true
            end
        end
        return false # if no child has that rule return false
    end
end



"""
    selectpsol_largest_subset(partial_sols::Vector{ProgramCache}}, all_selected_psols::Set{ProgramCache})) 

This scheme selects a single cheapest program (first enumerated) that 
satisfies the largest subset of examples encountered so far across all partial_sols.
"""
function selectpsol_largest_subset(partial_sols::Vector{ProgramCache}, all_selected_psols::Set{ProgramCache})
    if isempty(partial_sols)
        return Vector{ProgramCache}()
    end
    push!(partial_sols, all_selected_psols...)
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
    selectpsol_first_cheapest(partial_sols::Vector{ProgramCache}}, all_selected_psols::Set{ProgramCache})) 

This scheme selects a single cheapest program (first enumerated) that 
satisfies a unique subset of examples.
"""
function selectpsol_first_cheapest(partial_sols::Vector{ProgramCache}, all_selected_psol::Set{ProgramCache})
    # maps subset of examples to the cheapest program 
    mapping = Dict{Vector{Int},ProgramCache}()
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
    return collect(values(mapping))
end

"""
    selectpsol_all_cheapest(partial_sols::Vector{ProgramCache}, all_selected_psol::Set{ProgramCache}) 

This scheme selects all cheapest programs that satisfies a unique subset of examples.
"""
function selectpsol_all_cheapest(partial_sols::Vector{ProgramCache}, all_selected_psol::Set{ProgramCache})
    # maps subset of examples to the cheapest program 
    mapping = Dict{Vector{Int},Vector{ProgramCache}}()
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
    return collect(Iterators.flatten(values(mapping)))
end

function calculate_rule_cost_prob(rule_index, grammar)
    log_prob = grammar.log_probabilities[rule_index]
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