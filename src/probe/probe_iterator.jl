function probe(examples::Vector{<:IOExample}, iterator::ProgramIterator, select::Function, update!::Function, max_time::Int, iteration_size::Int)
    start_time = time()
    eval_cache = Set()
    state = nothing
    symboltable = SymbolTable(iterator.grammar)
    # start next iteration while there is time left
    while time() - start_time < max_time
        i = 1
        partial_sols = Vector()
        next = state === nothing ? iterate(iterator) : iterate(iterator, state)
        while next !== nothing && i < iteration_size # run one iteration
            program, state = next

            # evaluate program
            eval_observation = []
            nr_correct_examples = 0
            expr = rulenode2expr(program, iterator.grammar)
            for example ∈ examples
                output = execute_on_input(symboltable, expr, example.in)
                push!(eval_observation, output)

                if output == example.out
                    nr_correct_examples += 1
                end
            end

            if nr_correct_examples == length(examples) # found solution
                println("Last level: $(length(state.bank[state.level + 1])) programs")
                return program
            elseif eval_observation in eval_cache # result already in cache
                next = iterate(iterator, state)
                continue
            elseif nr_correct_examples >= 1 # partial solution
                push!(partial_sols, program)
            end

            push!(eval_cache, eval_observation)

            next = iterate(iterator, state)
            i += 1
        end

        # check if program iterator is exhausted
        if next === nothing
            return nothing
        end

        # partial_sols = select(partial_sols, eval_cache) # select promising partial solutions
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

# TODO: Have a nice way to switch from cost_size to cost_prob using multiple dispath maybe
calculate_rule_cost(rule_index, grammar::ContextSensitiveGrammar) = calculate_rule_cost_size(rule_index, grammar)

# generate in terms of increasing height
function newprograms(grammar, level, bank)
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
    symboltable = SymbolTable(iter.grammar)
    while state.level <= start_level + iter.level_limit
        # add another level to the bank that is empty
        push!(state.bank,[])
        new_programs = newprograms(iter.grammar, state.level, state.bank)
        if time() - start_time >= 10
            @warn "Probe took more than 10 seconds to run..."
            return (nothing, state)
        end
        for program ∈ new_programs
            # a list with all the outputs
            eval_observation = []
            nr_correct_examples = 0
            expr = rulenode2expr(program, iter.grammar)
            for example ∈ iter.spec
                output = execute_on_input(symboltable, expr, example.in)
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

