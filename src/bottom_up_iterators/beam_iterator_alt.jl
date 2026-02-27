"""
    abstract type AbstractBeamIteratorAlt <: ProgramIterator end

Abstract supertype for the beam iterator.
"""
abstract type AbstractBeamIteratorAlt <: ProgramIterator end

"""
    BeamIteratorAlt

An iterator that implements beam search. Given a heuristic cost function, beam seach works by maintaining a beam of the best N programs and expanding the beam sequentially.
Each iteration this iterator perform the following:
1. Return the next program from the beam that has not yet been returned
2. If the whole beam has been iterated over, create new programs by expanding each program from the beam with every possible extension
3. From the newly created programs, select the best N and replace the beam with these

The central datastructure that makes this iterator work is a beam. A beam is a collection of program such that:
- The beam never exceeds a certain size
- When adding a program to a full beam, the highest cost program is removed
- The beam never contains duplicates

One can specify the following parameters:
- `beam_size::Int=Inf`: the maximum amount of programs contained in the beam
- `max_extension_depth::Int=1`: the maximum depth of subprogram that programs from the beam get extended from
- `program_to_cost::Function`: the heuristic cost function taking an AbstractRuleNode and outputted a number
- `clear_beam_before_expansion::Bool=false`: if this is set to true, the beam is cleared before expansion, such that the beam is only filled with extended programs
- `stop_expanding_beam_once_replaced::Bool=true`: stop expanding beam programs once the entire beam has been replaced with better ones

""" BeamIteratorAlt

"""
    $(TYPEDEF)

Describes an entry in a [`beam`](@ref).
Holds the program, its associated cost and whether this program has already been expanded.
Extensions are also stored as BeamEntry's, but as they might not have the right type, a cost cannot always be computed, hence the Nothing type for the cost.
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

function Base.isless(a::BeamEntry, b::BeamEntry)
    return (a.cost, a.depth, a.size) < (b.cost, b.depth, b.size)
end


@programiterator BeamIteratorAlt(
    beam_size::Int=Inf,
    max_extension_depth::Int=1,
    max_extension_size::Int=1,
    program_to_cost::Union{Function,Nothing}=nothing,
    stop_expanding_beam_once_replaced::Bool=true,
    interpreter::Union{Function,Nothing}=nothing,
    observation_equivalance::Bool=false,
    beam::Vector{BeamEntry}=BeamEntry[],
    extensions::Vector{BeamEntry}=BeamEntry[],
) <: AbstractBeamIteratorAlt


"""
    Base.push_to_beam!(iter::AbstractBeamIteratorAlt, beam_entry::BeamEntry)

Adds a BeamEntry to the beam, ensuring that the beam size is not exceeded and only the best N programs are kept.
"""
function push_to_beam!(iter::AbstractBeamIteratorAlt, beam_entry::BeamEntry)
    # If the beam is full and the new entry has a higher cost than the worst in the beam, we can abort
    if length(iter.beam) >= iter.beam_size && beam_entry >= iter.beam[end]
        return nothing
    end

    # Otherwise, add the program to the beam
    # First, find the possible indices to add the new entry:
    #  - The last index in the array that has a lower cost
    #  - The first index in the array that has a higher cost
    first_index = searchsortedfirst(iter.beam, beam_entry)
    last_index = searchsortedlast(iter.beam, beam_entry)

    # To avoid duplicates or observational equivalance, we need to check each entry placed in this range and abort if the program or outputs are already present
    # If the cost was not present yet, last_index > first_index
    if first_index <= last_index
        for i in first_index:last_index
            # Check if the programs are equal
            if iter.beam[i].program == beam_entry.program
                return nothing
            end

            # Check if the outputs are equal
            if !isnothing(iter.interpreter) && iter.observation_equivalance && iter.beam[i].program._val == beam_entry.program._val
                return nothing
            end
        end
    end

    # Otherwise, insert the new entry
    insert!(iter.beam, last_index + 1, beam_entry)

    # If that exceeded the beam size, pop the worst entry
    if length(iter.beam) > iter.beam_size
        pop!(iter.beam)
    end

    return nothing
end

"""
    initialize!(iter::AbstractBeamIteratorAlt)

Initializes the iterator by creating all extensions and setting the first beam.
"""
function initialize!(iter::AbstractBeamIteratorAlt)
    # Copy the grammar to clear constraints
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
                cost = iter.program_to_cost(extension, nothing)
            else
                cost = nothing
            end

            beam_entry = BeamEntry(extension, cost, false, depth(extension), length(extension))

            # If it is a terminal with the correct output type and feasible with the original grammar constraints, add it to the first beam
            if type == get_starting_symbol(iter.solver) && all([check_tree(constraint, program) for constraint in grammar.constraints])
                 
                push_to_beam!(iter, beam_entry)
            end

            # Always add it to the set of extensions
            push!(iter.extensions, beam_entry)
        end
    end

    return nothing
end

function all_combinations(iter::AbstractBeamIteratorAlt, program::AbstractRuleNode)::Set{AbstractRuleNode}
    grammar = get_grammar(iter.solver)
    combinations = Set()

    # Replace this program with any extension of the same type
    for extension in iter.extensions
        # Check if they're the same type
        if grammar.types[get_rule(program)] == grammar.types[get_rule(extension.program)]
            push!(combinations, extension.program) 
        end
    end

    # Or don't and call this method on the children
    for (child_index, child) in enumerate(program.children)
        child_options = all_combinations(iter, child)

        for child_option in child_options
            new_children = [i != child_index ? c : child_option for (i, c) in enumerate(program.children)]
            combination = RuleNode(get_rule(program), new_children)
            push!(combinations, combination)
        end
    end

    return combinations
end

"""
    combine!(iter::AbstractBeamIteratorAlt)

Creates new programs by expanding all programs in the beam with all possible extensions.
Only selects the N best programs of these to create the new beam.
"""
function combine!(iter::AbstractBeamIteratorAlt)
    grammar = get_grammar(iter.solver)

    # Obtain the sorted programs from the beam and clear it for the new programs
    best_old_beam_entry = iter.beam[begin]
    old_beam = copy(iter.beam)

    # Iterate over all programs in the beam and expand them
    for beam_entry in old_beam
        # Optimization if enabled: once the whole beam has been replaced with new programs, terminate expansion
        # This is the case if the worst program in the new beam is better than the best in the old beam
        # Note that if `clear_beam_before_expansion`, the beam must be full before checking this
        if iter.stop_expanding_beam_once_replaced && length(iter.beam) == iter.beam_size && iter.beam[begin] < best_old_beam_entry
            break
        end

        # Iterate over combinations
        for program in all_combinations(iter, beam_entry.program)

            # If an interpreter is defined, set the _val of the rulenode
            if !isnothing(iter.interpreter)
                program._val = iter.interpreter(program)
            end
            
            # Create entry and bush to beam
            cost = iter.program_to_cost(program, nothing)
            entry_depth = depth(program)
            entry_size = length(program)
            new_entry = BeamEntry(program, cost, false, entry_depth, entry_size)
            push_to_beam!(iter, new_entry)
        end

        # Set the current beam entry has been expanded, change that field
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
    Base.iterate(iter::AbstractBeamIteratorAlt)

The initial call to the iterator. Initializes the beams and iterator's state.
"""
function Base.iterate(iter::AbstractBeamIteratorAlt)
    initialize!(iter)

    return Base.iterate(
        iter,
        BeamState(copy(iter.beam))
    )
end

"""
    Base.iterate(iter::AbstractBeamIteratorAlt)

Iterative call to the iterator. Perform the following:
1. If all programs from the current beam have been returned, expand the current beam and reset the iterator state.
2. If after expansion the beam is empty, kill the iterator.
3. Otherwise, return the next program from the beam and increment the pointer.
"""
function Base.iterate(iter::AbstractBeamIteratorAlt, state::BeamState)
    # If the current queue is drained, new programs must be created
    if isempty(state.queue)
        # If so, expand the current beam and reset the pointer
        state.queue = combine!(iter)
    end

    # Stop the iterator if the queue is empty; the iterator is exhausted
    if isempty(state.queue)
        return nothing
    end
    
    # Pop the first program from the queue and return
    return popfirst!(state.queue), state
end
