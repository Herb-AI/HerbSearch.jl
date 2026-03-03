abstract type AbstractPropertyBasedNeighborhoodIterator <: ProgramIterator end


mutable struct PoolEntry
    program::AbstractRuleNode
    cost::Number
    depth::Int
    size::Int
    has_been_expanded::Bool
    parent
end

PoolEntry(program::AbstractRuleNode, cost::Number, depth::Int, size::Int; parent=nothing) = PoolEntry(program, cost, depth, size, false, parent)

function Base.isless(a::PoolEntry, b::PoolEntry)
    a.cost != b.cost && return a.cost < b.cost
    # a.depth != b.depth && return a.depth < b.depth
    a.size != b.size && return a.size < b.size
    return false
end

function Base.:(==)(a::PoolEntry, b::PoolEntry)
    a.cost == b.cost &&
    a.depth == b.depth &&
    a.size == b.size &&
    a.program == b.program
end

@programiterator PropertyBasedNeighborhoodIterator(
    problem::Problem,
    interpreter::Function,
    pool_size::Int,
    candidate_properties::Vector{AbstractRuleNode},

    max_extension_depth::Int = 1,
    max_extension_size::Int = 1,
    
    pool::Vector{PoolEntry} = PoolEntry[],
    extensions::Vector{AbstractRuleNode} = AbstractRuleNode[],
    selected_properties::Vector{AbstractRuleNode} = AbstractRuleNode[],

    max_number_of_properties::Int = typemax(Int),

    property_grammar = grammar,
) <: AbstractPropertyBasedNeighborhoodIterator


function heuristic_cost(iter::PropertyBasedNeighborhoodIterator, program::AbstractRuleNode)::Int
    spec = iter.problem.spec
    interp = iter.interpreter

    if isnothing(program._val) || length(program._val) == 0
        program._val = [interp(program, io.in) for io in spec]
    end

    outputs = program._val

    if any(isnothing, outputs)
        return typemax(Int)
    end

    if all(output == io.out for (output, io) in zip(outputs, spec))
        return -1
    end

    return count(
        interp(property, (io.in[:_arg_out] = output; io.in)) != interp(property, (io.in[:_arg_out] = io.out; io.in))
        for (output, io) in zip(outputs, spec)
        for property in iter.selected_properties
    )
end


"""
    Base.add_to_pool!(iter::AbstractBeamIterator, beam_entry::BeamEntry)

Adds a program to the pool, ensuring that the pool size is not exceeded and only the best programs are kept.
"""
function add_to_pool!(iter::PropertyBasedNeighborhoodIterator, program::AbstractRuleNode, parent=nothing)    
    cost = heuristic_cost(iter, program)
    pool_entry = PoolEntry(program, cost, depth(program), length(program); parent = parent)

    # If the cost is infinity, skip the program
    if cost == Inf
        return nothing
    end

    # If the beam is full and the new entry has a higher cost than the worst in the beam, we can abort
    if length(iter.pool) >= iter.pool_size && pool_entry >= iter.pool[end]
        # println("Worse than pool")
        return nothing
    end

    #= Otherwise, add the program to the beam
    
    The main difficulty is checking whether a equal (or equivalent program with observation_equivalance) exists in the beam.
    For this, we only wish to check the programs (or outputs) for beam entries that have the same cost.
    
    For this we find the range of equal costs: 
     - The last index in the array that has a lower cost
     - The first index in the array that has a higher cost
    =#
    first_index = searchsortedfirst([e.cost for e in iter.pool], pool_entry.cost)
    last_index = searchsortedlast([e.cost for e in iter.pool], pool_entry.cost)

    # @show first_index
    # @show last_index

    # If last_index > first_index, there is no entry with the same cost, and this step can be skipped
    if first_index <= last_index
        
        # To avoid duplicates, we check every beam entry in this range and see if the program or outputs are already present
        for i in first_index:last_index

            # Check if the programs are equal; abort if so
            if iter.pool[i].program == program
                return nothing
            end

            # If an interpreter is supplied and we have observation_equivalance, check if the outputs are equal; keep the shortest program in that case
            if iter.pool[i].program._val == program._val
                if pool_entry < iter.pool[i]
                    iter.pool[i] = pool_entry
                end

                return nothing
            end
        end
    end

    index = searchsortedlast(iter.pool, pool_entry)

    # If the entry made it through all the checks above, insert it
    insert!(iter.pool, index + 1, pool_entry)

    # If that exceeded the beam size, pop the worst entry (located at the end)
    if length(iter.pool) > iter.pool_size
        pop!(iter.pool)
    end

    return nothing
end

"""
    initialize!(iter::AbstractBeamIterator)

Initializes the iterator by creating all extensions and setting the first beam.
"""
function initialize!(iter::PropertyBasedNeighborhoodIterator)
    # Copy the grammar to clear constraints as we will use another iterator to obtain extensions
    original_grammar = get_grammar(iter.solver)
    grammar = deepcopy(original_grammar)
    clearconstraints!(grammar)

    # Iterate over all grammar types
    for type in unique(grammar.types)
        # Itertate over all extensions of that type up to the specified depth and size
        extensions = BFSIterator(grammar, type, 
            max_depth=iter.max_extension_depth,
            max_size=iter.max_extension_size)

        for extension in extensions
            extension = freeze_state(extension)

            # If an interpreter is defined, set the _val of the rulenode
            extension._val = [iter.interpreter(extension, io.in) for io in iter.problem.spec]

            # If this extension produces an error or an already existing output, skip it
            if any(isnothing, extension._val) || any(e._val == extension._val for e in iter.extensions)
                continue
            end

            # If it has the correct output type and is feasible with the original grammar constraints, add it to the first beam
            if type == get_starting_symbol(iter.solver) && all([check_tree(constraint, extension) for constraint in grammar.constraints])
                cost = heuristic_cost(iter, extension)
                add_to_pool!(iter, extension)
            end

            # Always add it to the set of extensions
            push!(iter.extensions, extension)
        end
    end

    return nothing
end

function neighborhood(iter::PropertyBasedNeighborhoodIterator, program::AbstractRuleNode)
    grammar = get_grammar(iter.solver)
    types = grammar.types

    function extend(program::AbstractRuleNode)
        program_type = types[get_rule(program)]
        combinations = Set()

        # for child in program.children
        #     if types[get_rule(child)] == program_type
        #         push!(combinations, child)
        #     end
        # end

        for rule_id in 1:length(grammar.rules)
            if types[rule_id] != program_type
                continue
            end

            for program_index in [0; findall(t -> t == program_type, grammar.childtypes[rule_id])]
                child_options = []

                for (index, child_type) in enumerate(grammar.childtypes[rule_id])
                    if index == program_index
                        push!(child_options, [program])
                    else
                        push!(child_options, [e for e in iter.extensions if child_type == types[get_rule(e)]])
                    end
                end

                for child_tuple in Iterators.product(child_options...)
                    children = collect(child_tuple)
                    new_program = RuleNode(rule_id, children)

                    if any([!check_tree(constraint, program) for constraint in grammar.constraints])
                        continue
                    end

                    push!(combinations, new_program)
                end
            end
        end

        return combinations
    end

    function extend_all_nodes(program::AbstractRuleNode)
        results = extend(program)

        for (child_index, child) in enumerate(program.children)
            new_child_options = extend_all_nodes(child)

            for new_child in new_child_options
                new_children = [i == child_index ? new_child : c for (i, c) in enumerate(program.children)]
                new_program = RuleNode(get_rule(program), new_children)
                push!(results, new_program)
            end
        end

        return results
    end

    return extend_all_nodes(program)
end

"""
    combine!(iter::AbstractBeamIterator)

Creates new programs by expanding all programs in the beam with all possible extensions.
Only selects the N best programs of these to create the new beam.
"""
function combine!(iter::PropertyBasedNeighborhoodIterator)
    worst_pool_entry = iter.pool[end]
    
    for (i, pool_entry) in enumerate([e for e in iter.pool[1:1]])
        if pool_entry.has_been_expanded
            continue
        end

        # if length(iter.pool) == iter.pool_size && iter.pool[end] < worst_pool_entry
        #     break
        # end

        for neighbor in neighborhood(iter, pool_entry.program)
            parent = (pool_entry, i)
            add_to_pool!(iter, neighbor, parent)

            # if iter.pool[begin].cost == -1
            #     return [iter.pool[begin].program]
            # end
        end

        pool_entry.has_been_expanded = true
    end

    # neighbors = Set()
    # for pool_entry in [e for e in iter.pool]
    #     if pool_entry.has_been_expanded
    #         continue
    #     end

    #     union!(neighbors, neighborhood(iter, pool_entry.program))
    #     pool_entry.has_been_expanded = true
    # end

    # for neighbor in neighbors
    #     add_to_pool!(iter, neighbor)

    #     # if iter.pool[begin].cost == -1
    #     #     return [iter.pool[begin].program]
    #     # end
    # end

    # Only return programs that have not been expanded yet, otherwise they are already iterated over
    return [pool_entry.program for pool_entry in iter.pool[1:1] if !pool_entry.has_been_expanded]
end

function refine_heuristic!(iter::PropertyBasedNeighborhoodIterator)
    interp = iter.interpreter

    optimal_heuristic_increase = count(output != io.out for pool_entry in iter.pool for (output, io) in zip(pool_entry.program._val, iter.problem.spec) if !any(isnothing, pool_entry.program._val))
    best_property = nothing
    best_property_index = -1
    best_heuristic_increase = -1

    unsafe_properties = []
    for (property_index, property) in enumerate(iter.candidate_properties)
        if property in iter.selected_properties
            continue
        end

        # increase = count(
        #     interp(property, (io.in[:_arg_out] = output; io.in)) != interp(property, (io.in[:_arg_out] = io.out; io.in))
        #     for pool_entry in iter.pool
        #     for (output, io) in zip(pool_entry.program._val, iter.problem.spec)
        # )

        target_values = [interp(property, (io.in[:_arg_out] = io.out; io.in)) for io in iter.problem.spec]

        # if !allequal(target_values)
        #     continue
        # end

        if any(isnothing, target_values)
            push!(unsafe_properties, property_index)
            continue
        end

        increase = 0
        for pool_entry in iter.pool
            if any(isnothing, pool_entry.program._val)
                continue
            end

            values = [interp(property, (io.in[:_arg_out] = output; io.in)) for (output, io) in zip(pool_entry.program._val, iter.problem.spec)]
            
            # if any(isnothing, target_values) || any(isnothing, values)
            #     push!(unsafe_properties, property_index)
            #     increase = -1
            #     break
            # end

            increase += sum(values .!= target_values)
        end

        if increase == 0
            prop = rulenode2expr(property, iter.property_grammar)
            @show 0, prop
        end

        if increase > best_heuristic_increase
            best_property = property
            best_property_index = property_index
            best_heuristic_increase = increase

            if increase >= optimal_heuristic_increase * 0.8
                # break
                push!(iter.selected_properties, best_property)
                deleteat!(iter.candidate_properties, unsafe_properties)
                
                println("\nAdded property ($best_heuristic_increase / $optimal_heuristic_increase)")
                prop = rulenode2expr(best_property, iter.property_grammar)
                @show prop
            end
        end
    end

    # push!(iter.selected_properties, best_property)
    # deleteat!(iter.candidate_properties, unsafe_properties)
    
    # println("\nAdded property ($best_heuristic_increase / $optimal_heuristic_increase)")
    # prop = rulenode2expr(best_property, iter.property_grammar)
    # @show prop

    return nothing
end


"""
    Base.iterate(iter::AbstractBeamIterator)

The initial call to the iterator. Initializes the beams and iterator's state.
"""
function Base.iterate(iter::PropertyBasedNeighborhoodIterator)
    initialize!(iter)

    return Base.iterate(
        iter,
        [pool_entry.program for pool_entry in iter.pool[1:1]]
    )
end

"""
    Base.iterate(iter::AbstractBeamIterator)

Iterative call to the iterator. Perform the following:
1. If all programs from the current queue have been returned, expand the current beam and set the queue as the new beam (pruning already returned programs).
2. If after expansion the beam is empty, the iterator is exhausted.
3. Otherwise, return the next program from the queue.
"""
function Base.iterate(iter::PropertyBasedNeighborhoodIterator, state::Vector{<:AbstractRuleNode})
    # If the current queue is drained, new programs must be created
    if isempty(state)
        # If so, expand the current pool and set that result as the queue
        # println("\nCombine!")
        state = combine!(iter)
    end

    # If the queue is empty, the search has reached a local optima; 
    # - refine the heuristic
    # - set pool entries to not expanded yet and recompute cost
    # - call this method again so that combine is recalled
    if isempty(state)
        if length(iter.selected_properties) >= iter.max_number_of_properties
            return nothing
        end

        refine_heuristic!(iter)

        # for pool_entry in iter.pool
        #     pool_entry.has_been_expanded = false
        #     pool_entry.cost = heuristic_cost(iter, pool_entry.program)
        # end

        empty!(iter.pool)
        
        for e in iter.extensions 
            if get_grammar(iter.solver).types[get_rule(e)] == get_starting_symbol(iter)
                add_to_pool!(iter, e)
            end
        end

        state = [pool_entry.program for pool_entry in iter.pool[1:1]]

        return Base.iterate(iter, state)
    end
    
    # Pop the first program from the queue and return
    return popfirst!(state), state
end