"""
    abstract type AbstractBeamIterator <: ProgramIterator end

Abstract supertype for the beam iterator.
"""
abstract type AbstractBeamIterator <: ProgramIterator end

"""
    BeamIterator

An iterator that implements beam search. Given a heuristic cost function, beam seach works by maintaining a set of the best N programs and expanding the them sequentially.
Each iteration this iterator perform the following:
1. Return the next program from the beam that has not yet been returned
2. If the whole beam has been iterated over, create new programs by expanding each program from the beam with every possible extension
3. From the newly created programs, select the best N and replace the beam with these

The central datastructure that makes this iterator work is a beam. A beam is a collection of program such that:
- The beam never exceeds a certain size
- When adding a program to a full beam, the highest cost program is removed
- The beam never contains duplicates
The beam is implemented with a sorted array. This structure easily allows highest and lowest cost lookups and efficient membership testing.

One can specify the following parameters:
- `beam_size::Int=10`: the maximum amount of programs contained in the beam
- `max_extension_depth::Int=1`: the maximum depth of subprograms that beam programs get extended with
- `max_extension_size::Int=1`: the maximum size of subprograms that beam programs get extended with
- `program_to_cost::Function`: the heuristic cost function taking an AbstractRuleNode and outputted a number
- `stop_expanding_beam_once_replaced::Bool=true`: stop expanding beam programs once the entire beam has been replaced with better ones

""" BeamIterator

"""
    $(TYPEDEF)

Describes an entry in a [`beam`](@ref).
Holds the program, its associated cost and whether this program has already been expanded.
Extensions are also stored as BeamEntry's, but as they might not have the right type to compute a cost, hence the additional Nothing type for the cost.
Also caches the depth and size for easy computation of these for composite programs.
"""
mutable struct BeamEntry
    program::AbstractRuleNode
    cost::Union{Number,Nothing}
    has_been_expanded::Bool
    depth::Int
    size::Int
end

get_program(beam_entry::BeamEntry) = beam_entry.program
HerbCore.depth(beam_entry::BeamEntry) = beam_entry.depth
Base.size(beam_entry::BeamEntry) = beam_entry.size


@programiterator BeamIterator(
    beam_size::Int=10,
    max_extension_depth::Int=1,
    max_extension_size::Int=1,
    program_to_cost::Union{Function,Nothing}=nothing,
    stop_expanding_beam_once_replaced::Bool=true,
    interpreter::Union{Function,Nothing}=nothing,
    observational_equivalance::Bool=false,
    beam::Vector{BeamEntry}=BeamEntry[],
    extensions::Vector{BeamEntry}=BeamEntry[],
) <: AbstractBeamIterator

"""
    highest_cost(iter::AbstractBeamIterator)

Returns the cost of the worst program in the beam.
"""
highest_cost(iter::AbstractBeamIterator) = iter.beam[end].cost

"""
    lowest_cost(iter::AbstractBeamIterator)

Returns the cost of the best program in the beam.
"""
lowest_cost(iter::AbstractBeamIterator) = iter.beam[begin].cost

"""
    Base.push_to_beam!(iter::AbstractBeamIterator, beam_entry::BeamEntry)

Adds a BeamEntry to the beam, ensuring that the beam size is not exceeded and only the best programs are kept.
"""
function push_to_beam!(iter::AbstractBeamIterator, beam_entry::BeamEntry)
    # If the beam is full and the new entry has a higher cost than the worst in the beam, we can abort
    if length(iter.beam) >= iter.beam_size && beam_entry.cost >= highest_cost(iter)
        return nothing
    end

    #= Otherwise, add the program to the beam
    
    The main difficulty is checking whether a equal (or equivalent program with observation_equivalance) exists in the beam.
    For this, we only wish to check the programs (or outputs) for beam entries that have the same cost.
    
    For this we find the range of equal costs: 
     - The last index in the array that has a lower cost
     - The first index in the array that has a higher cost
    =#
    first_index = searchsortedfirst([e.cost for e in iter.beam], beam_entry.cost)
    last_index = searchsortedlast([e.cost for e in iter.beam], beam_entry.cost)

    # If last_index > first_index, there is no entry with the same cost, and this step can be skipped
    if first_index <= last_index
        
        # To avoid duplicates, we check every beam entry in this range and see if the program or outputs are already present
        for i in first_index:last_index

            # Check if the programs are equal; abort if so
            if iter.beam[i].program == beam_entry.program
                return nothing
            end

            # If an interpreter is supplied and we have observation_equivalance, check if the outputs are equal; abort if so
            if !isnothing(iter.interpreter) && iter.observational_equivalance && iter.beam[i].program._val == beam_entry.program._val
                return nothing
            end
        end
    end

    # If the entry made it through all the checks above, insert it
    insert!(iter.beam, first_index, beam_entry)

    # If that exceeded the beam size, pop the worst entry (located at the end)
    if length(iter.beam) > iter.beam_size
        pop!(iter.beam)
    end

    return nothing
end

"""
    initialize!(iter::AbstractBeamIterator)

Initializes the iterator by creating all extensions and setting the first beam.
"""
function initialize!(iter::AbstractBeamIterator)
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
                extension._val = iter.interpreter(extension)
            end

            # Create beam entry
            # Cost can only be computed if the extension type is the output type
            if type == get_starting_symbol(iter.solver)
                cost = iter.program_to_cost(extension)
            else
                cost = nothing
            end

            beam_entry = BeamEntry(extension, cost, false, depth(extension), length(extension))

            # If it has the correct output type and is feasible with the original grammar constraints, add it to the first beam
            # TODO: not sure if this is the best way to check against all constraints. If anyone knows how, please improve :)
            if type == get_starting_symbol(iter.solver) && isfeasible(UniformSolver(original_grammar, extension))
                push_to_beam!(iter, beam_entry)
            end

            # Always add it to the set of extensions
            push!(iter.extensions, beam_entry)
        end
    end

    return nothing
end

"""
    combine!(iter::AbstractBeamIterator)

Creates new programs by expanding all programs in the beam with all possible extensions.
Only selects the N best programs of these to create the new beam.
"""
function combine!(iter::AbstractBeamIterator)
    grammar = get_grammar(iter.solver)

    # Finds all nonterminal shapes to combine the beam and termianls with
    terminals_mask     = grammar.isterminal
    nonterminals_mask  = .~terminals_mask
    return_type_mask   = grammar.types .== get_starting_symbol(iter.solver)
    nonterminal_shapes = UniformHole.(partition(Hole(nonterminals_mask .& return_type_mask), grammar), ([],))

    # Computes whether a combination exceed the maximum depth or size
    is_feasible = function(children::Tuple{Vararg{BeamEntry}})
        (get_max_depth(iter) == typemax(Int) || maximum(depth.(children)) < get_max_depth(iter)) &&
        (get_max_size(iter) == typemax(Int) || sum(size.(children)) < get_max_size(iter))
    end

    # Gives a BeamEntry's return type
    get_return_type(beam_entry::BeamEntry) = grammar.types[get_rule(beam_entry.program)]

    # Given the types of children, creates a filter to obtain well typed expressions
    is_well_typed = child_types -> (children -> child_types == get_return_type.(children))

    # Obtain the sorted programs from the beam and clear it for the new programs
    best_old_beam_cost = lowest_cost(iter)
    old_beam = copy(iter.beam)

    # Iterate over all programs in the beam and expand them
    for beam_entry in old_beam
        # Optimization if enabled: once the whole beam has been replaced with new programs, terminate expansion
        # This is the case if the worst program in the new beam is better than the best in the old beam
        # Note that the beam must be full before checking this
        if iter.stop_expanding_beam_once_replaced && length(iter.beam) == iter.beam_size && lowest_cost(iter) < best_old_beam_cost
            break
        end

        # Iterate over all shapes to expand with and obtain their types, arity and type filter
        for shape in nonterminal_shapes
            child_types  = Tuple(grammar.childtypes[findfirst(shape.domain)])
            arity        = length(child_types)
            typed_filter = is_well_typed(child_types)

            # A program from the beam can in be one of the child positions
            for beam_index in 1:arity
                # Children only can be from the extension set, execpt at the beam index where we place the beam program
                potential_children = collect(Iterators.repeated(iter.extensions, arity))
                potential_children[beam_index] = [beam_entry]

                # Obtain all possible combinations that are well typed and feasible in the depth and size limit
                candidate_combinations = Iterators.product(potential_children...)
                candidate_combinations = Iterators.filter(typed_filter, candidate_combinations)
                candidate_combinations = Iterators.filter(is_feasible, candidate_combinations)

                # Iterate over all possible programs and add them to the beam
                for child_tuple in candidate_combinations
                    for rule_idx in findall(shape.domain)
                        children = collect(child_tuple)
                        program = RuleNode(rule_idx, get_program.(children))

                        # Check if the program is feasible with the constraints
                        # TODO: not sure if this is the best way to check against all constraints. If anyone knows how, please improve :)
                        if !isfeasible(UniformSolver(grammar, program))
                            continue
                        end

                        # If an interpreter is defined, set the _val of the rulenode
                        if !isnothing(iter.interpreter)
                            program._val = iter.interpreter(program)
                        end
                        
                        # Compute cost, depth and sizes
                        cost = iter.program_to_cost(program)
                        entry_depth = maximum(depth.(children)) + 1
                        entry_size = sum(size.(children)) + 1
                        new_entry = BeamEntry(program, cost, false, entry_depth, entry_size)

                        push_to_beam!(iter, new_entry)
                    end
                end
            end
        end

        # Change the current beam entry to expanded
        beam_entry.has_been_expanded = true
    end

    # Only return programs that have not been expanded yet, otherwise they are already iterated over
    return [entry for entry in copy(iter.beam) if !entry.has_been_expanded]
end

"""
    mutable struct BeamState

The iterator state for a beam iterator contains a queue that is a copy of the programs in the beam sorted on increasing cost.
"""
mutable struct BeamState
    queue::Vector{BeamEntry}
end

"""
    Base.iterate(iter::AbstractBeamIterator)

The initial call to the iterator. Initializes the beams and iterator's state.
"""
function Base.iterate(iter::AbstractBeamIterator)
    initialize!(iter)

    return Base.iterate(
        iter,
        BeamState(copy(iter.beam))
    )
end

"""
    Base.iterate(iter::AbstractBeamIterator)

Iterative call to the iterator. Perform the following:
1. If all programs from the current queue have been returned, expand the current beam and set the queue as the new beam (pruning already returned programs).
2. If after expansion the beam is empty, the iterator is exhausted.
3. Otherwise, return the next program from the queue.
"""
function Base.iterate(iter::AbstractBeamIterator, state::BeamState)
    # If the current queue is drained, new programs must be created
    if isempty(state.queue)
        # If so, expand the current beam and set that result as the queue
        state.queue = combine!(iter)
    end

    # Stop the iterator if the queue is empty; the iterator is exhausted
    if isempty(state.queue)
        return nothing
    end
    
    # Pop the first program from the queue and return
    return popfirst!(state.queue).program, state
end