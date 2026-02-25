abstract type AbstractPropertyBasedNeighborhoodIterator <: ProgramIterator end


mutable struct PoolEntry
    program::AbstractRuleNode
    cost::Number
    depth::Int
    size::Int
    has_been_expanded::Bool
end

PoolEntry(program::AbstractRuleNode, cost::Number, depth::Int, size::Int) = PoolEntry(program, cost, depth, size, false)

function Base.isless(a::PoolEntry, b::PoolEntry)
    a.cost != b.cost && return a.cost < b.cost
    a.depth != b.depth && return a.depth < b.depth
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

    if isnothing(program._val)
        program._val = [interp(program, io.in) for io in spec]
    end

    outputs = program._val

    if any(isnothing, outputs)
        return typemax(Int)
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
function add_to_pool!(iter::PropertyBasedNeighborhoodIterator, program::AbstractRuleNode)
    cost = heuristic_cost(iter, program)
    pool_entry = PoolEntry(program, cost, depth(program), length(program))

    # println()
    # @show iter.pool
    # @show program
    # @show cost

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
    first_index = searchsortedfirst(iter.pool, pool_entry)
    last_index = searchsortedlast(iter.pool, pool_entry)

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

            # If an interpreter is supplied and we have observation_equivalance, check if the outputs are equal; abort if so
            if iter.pool[i].program._val == program._val
                return nothing
            end
        end
    end

    # If the entry made it through all the checks above, insert it
    insert!(iter.pool, last_index + 1, pool_entry)

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
            if !isnothing(iter.interpreter)
                extension._val = [iter.interpreter(extension, io.in) for io in iter.problem.spec]
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

function neighborhood(iter::PropertyBasedNeighborhoodIterator, program::AbstractRuleNode)::Vector{<:AbstractRuleNode}
    types = get_grammar(iter).types

    #= 
    
    Neighbors of a program come in three forms:
      
    1. Growing:                 For each extensions replace a terminal with the program
    2. Growing and shrinking:   For each node in the program with depth/size less or equal to extensions, replace it with another extension
    3. Shrinking:               Take each child of the program


    =#

    function neighborhood1(extension, program)
        if length(extension.children) == 0
            return types[get_rule(extension)] == types[get_rule(program)] ? [program] : []
        end

        results = []
        for (i1, child) in enumerate(extension.children)
            new_childs = neighborhood1(child, program)

            for new_child in new_childs
                new_children = [i1 == i2 ? new_child : c for (i2, c) in enumerate(extension.children)]
                new_program = RuleNode(get_rule(extension), new_children)
                push!(results, new_program)
            end
        end

        return results
    end

    function neighborhood2(program)
        results = []

        if depth(program) <= iter.max_extension_depth && length(program) <= iter.max_extension_size
            append!(results, [e for e in iter.extensions if types[get_rule(e)] == types[get_rule(program)]])
        end

        for (i1, child) in enumerate(program.children)
            new_childs = neighborhood2(child)

            for new_child in new_childs
                new_children = [i1 == i2 ? new_child : c for (i2, c) in enumerate(program.children)]
                new_program = RuleNode(get_rule(program), new_children)
                push!(results, new_program)
            end
        end

        return results
    end
    
    function neighborhood3(program)
        return [c for c in program.children if types[get_rule(c)] == types[get_rule(program)]]
    end

    neighbors = Set{AbstractRuleNode}()

    
    [union!(neighbors, neighborhood1(extension, program)) for extension in iter.extensions if types[get_rule(extension)] == types[get_rule(program)]]
    union!(neighbors, neighborhood2(program))
    union!(neighbors, neighborhood3(program))

    return collect(neighbors)
end

"""
    combine!(iter::AbstractBeamIterator)

Creates new programs by expanding all programs in the beam with all possible extensions.
Only selects the N best programs of these to create the new beam.
"""
function combine!(iter::PropertyBasedNeighborhoodIterator)
    worst_pool_entry = iter.pool[end]
    
    for pool_entry in [e for e in iter.pool]
        if pool_entry.has_been_expanded
            continue
        end

        if length(iter.pool) == iter.pool_size && iter.pool[end] < worst_pool_entry
            break
        end

        @show pool_entry

        for neighbor in neighborhood(iter, pool_entry.program)
            add_to_pool!(iter, neighbor)
        end

        pool_entry.has_been_expanded = true
    end

    # Only return programs that have not been expanded yet, otherwise they are already iterated over
    return [pool_entry.program for pool_entry in iter.pool if !pool_entry.has_been_expanded]
end

function refine_heuristic!(iter::PropertyBasedNeighborhoodIterator)
    interp = iter.interpreter

    optimal_heuristic_increase = length(iter.pool) * length(iter.problem.spec)
    best_property = nothing
    best_heuristic_increase = -1

    for property in iter.candidate_properties
        if property in iter.selected_properties
            continue
        end

        increase = count(
            interp(property, (io.in[:_arg_out] = output; io.in)) != interp(property, (io.in[:_arg_out] = io.out; io.in))
            for pool_entry in iter.pool
            for (output, io) in zip(pool_entry.program._val, iter.problem.spec)
        )

        if increase > best_heuristic_increase
            best_property = property
            best_heuristic_increase = increase

            if increase == optimal_heuristic_increase
                break
            end
        end
    end

    push!(iter.selected_properties, best_property)
    
    # println("\nAdded property")
    # prop = rulenode2expr(best_property, iter.property_grammar)
    # @show prop
    # @show [e.program._val for e in iter.pool]
    # @show best_heuristic_increase

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
        [pool_entry.program for pool_entry in iter.pool]
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

        for pool_entry in iter.pool
            pool_entry.has_been_expanded = false
            pool_entry.cost = heuristic_cost(iter, pool_entry.program)
        end

        # @show iter.pool

        return Base.iterate(iter, state)
    end
    
    # Pop the first program from the queue and return
    return popfirst!(state), state
end