"""
    abstract type AbstractBeamIterator <: ProgramIterator end

Abstract supertype for the beam iterator.
"""
abstract type AbstractBeamIterator <: ProgramIterator end

"""
    BeamIterator

An iterator that implements beam search. Given a heuristic cost function, beam seach works by maintaining a beam of the best N programs and expanding the beam sequentially.
Each iteration this iterator perform the following:
1. Return the next program from the beam that has not yet been returned
2. If the whole beam has been iterated over, create new programs by expanding each program from the beam with every possible terminal
3. From the newly created programs, select the best N and replace the beam with these

The central datastructure that makes this iterator work is a beam. Given heuristic cost function, a beam is a collection of program such that:
- The beam size never exceeds a set amount of programs
- When adding a program to a full beam, the lowest cost program according to the heuristic cost function is kept
- Adding programs is O(1)
- The beam may contains duplicate programs


One can specify the following parameters:
- `beam_size::Int=Inf`: the maximum amount of programs contained in the beam
- `max_extension_depth::Int=1`: the maximum depth of subprogram that programs from the beam get extended from
- `program_to_cost::Function`: the heuristic cost function taking an AbstractRuleNode and outputted a number
- `clear_beam_before_expansion::Bool=false`: if this is set to true, the beam is cleared before expansion, such that the beam is only filled with extended programs
- `stop_expanding_beam_once_replaced::Bool=true`: stop expanding beam programs once the entire beam has been replaced with better ones

""" BeamIterator

"""
    $(TYPEDEF)

Describes an entry in a [`beam`](@ref).
Holds the program, its associated cost and whether this program has already been expanded.
"""
mutable struct BeamEntry
    program::AbstractRuleNode
    cost::Number
    has_been_expanded::Bool
    depth::Int
    size::Int
end

"""
    Base.isless(a::BeamEntry, b::BeamEntry)

Compares two BeamEntry's based on their associated costs.
"""
Base.isless(a::BeamEntry, b::BeamEntry) = a.cost < b.cost

# TODO: doc
Base.:(==)(a::BeamEntry, b::BeamEntry) = a.cost == b.cost && a.program == b.program

get_program(beam_entry::BeamEntry) = beam_entry.program
HerbCore.depth(beam_entry::BeamEntry) = beam_entry.depth
Base.size(beam_entry::BeamEntry) = beam_entry.size


"""
   struct Beam

A beam that contains at most N programs, only keeping the best.
One can push programs to a beam and this object ensures that the best N programs are kept.
Note that on expansion programs can be created that already exist in the beam, making the beam not necissarily unique.

This struct contains:
- Beam size: the maximum number of programs in the beam
- Heuristic cost function: given a program, computes its associated cost
- Program heap: contains the program, ensuring that the highest cost can be obtained efficiently
"""
struct Beam
    beam_size::Number
    program_to_cost::Function
    programs::Union{MutableBinaryMaxHeap{BeamEntry}}
end

"""
    Beam(beam_size::Number, program_to_cost::Function)::Beam

Creates a new empty beam given its size and heuristic cost function.
"""
Beam(beam_size::Number, program_to_cost::Function)::Beam = Beam(beam_size, program_to_cost, MutableBinaryMaxHeap{BeamEntry}())

"""
    clear!(beam::Beam)

Resets the beam, removing all programs from it. 
"""
function clear!(beam::Beam)
    beam.programs = MutableBinaryMaxHeap{BeamEntry}()
    return nothing
end

"""
    Base.push!(beam::Beam, program::RuleNode)

Adds a program to the beam, ensuring that the beam size is not exceeded and only the best program is kept.
"""
function Base.push!(beam::Beam, beam_entry::BeamEntry)
    # If the program heap is nothing, the beam has been concretized
    # This ensures that no programs are pushed to a concretized beam
    @assert !isnothing(beam.programs)

    # If the beam has not been filled yet, add the program to the beam
    if length(beam.programs) < beam.beam_size
        push!(beam.programs, beam_entry)
        return nothing
    end

    # Most programs we attempt to add to the beam have a higher cost than the worst
    # Check this first to avoid costly dictionary lookups
    if beam_entry.cost >= first(beam.programs).cost
        return nothing
    end

    # Otherwise, pop the worst program and add the new one to the beam
    pop!(beam.programs)
    push!(beam.programs, beam_entry)

    return nothing
end

"""
    get_expandable_entries(beam::Beam)::Vector{BeamEntry}

Returns all BeamEntry that have not been expanded yet.
"""
function get_expandable_entries(beam::Beam)::Vector{BeamEntry}
    entries = extract_all!(beam.programs)

    for entry in entries
        push!(beam.programs, entry)
    end
    
    return [e for e in entries if !e.has_been_expanded]
end

@programiterator BeamIterator(
    beam_size::Int=Inf,
    max_extension_depth::Int=1,
    max_extension_size::Int=1,
    program_to_cost::Union{Function,Nothing}=nothing,
    clear_beam_before_expansion::Bool=false,
    stop_expanding_beam_once_replaced::Bool=true,
    interpreter::Union{Function,Nothing}=nothing,
    beam=Beam(beam_size, program_to_cost),
    extensions::Vector{BeamEntry}=BeamEntry[],
) <: AbstractBeamIterator

"""
    initialize!(iter::AbstractBeamIterator)

Initializes the iterator by creating all extensions and setting the first beam.
"""
function initialize!(iter::AbstractBeamIterator)
    grammar = get_grammar(iter.solver)

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

            # If it is a terminal with the correct output type, add it to the first beam
            if type == get_starting_symbol(iter.solver) && length(extension) == 1
                push!(iter.beam, beam_entry)
            end

            # Always add it to the set of extensions
            push!(iter.extensions, beam_entry)
        end
    end

    @show length(iter.extensions)

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
    old_beam = get_expandable_entries(iter.beam)
    best_old_beam_cost = last(old_beam).cost

    # Clear the beam if specified
    if iter.clear_beam_before_expansion
        clear!(iter.beam)
    end

    # Iterate over all programs in the beam and expand them
    for beam_entry in old_beam
        # Optimization if enabled: once the whole beam has been replaced with new programs, terminate expansion
        # This is the case if the worst program in the new beam is better than the best in the old beam
        # Note that if `clear_beam_before_expansion`, the beam must be full before checking this
        if iter.stop_expanding_beam_once_replaced && length(iter.beam.programs) == iter.beam_size && first(iter.beam.programs).cost < best_old_beam_cost
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

                        # If an interpreter is defined, set the _val of the rulenode
                        if !isnothing(iter.interpreter)
                            program._val = iter.interpreter(program)
                        end

                        cost = iter.program_to_cost(program, children)
                        entry_depth = maximum(depth.(children)) + 1
                        entry_size = sum(size.(children)) + 1
                        new_entry = BeamEntry(program, cost, false, entry_depth, entry_size)

                        push!(iter.beam, new_entry)
                    end
                end
            end
        end

        # Set the current beam entry has been expanded, change that field
        beam_entry.has_been_expanded = true
    end

    # Only return programs that have not been expanded yet, otherwise they are already iterated over
    return get_expandable_entries(iter.beam)
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
        BeamState(get_expandable_entries(iter.beam))
    )
end

"""
    Base.iterate(iter::AbstractBeamIterator)

Iterative call to the iterator. Perform the following:
1. If all programs from the current beam have been returned, expand the current beam and reset the iterator state.
2. If after expansion the beam is empty, kill the iterator.
3. Otherwise, return the next program from the beam and increment the pointer.
"""
function Base.iterate(iter::AbstractBeamIterator, state::BeamState)
    # If the current queue is drained, new programs must be created
    if isempty(state.queue)
        # If so, expand the current beam and reset the pointer
        state.queue = combine!(iter)

        println("\n\nCombined")
    end

    # Stop the iterator if the queue is empty; the iterator is exhausted
    if isempty(state.queue)
        return nothing
    end
    
    # Pop the next program from the queue and return
    return pop!(state.queue).program, state
end
