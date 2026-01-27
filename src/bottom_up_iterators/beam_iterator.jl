#=

Does not use the bottom-up interface as that is fine tuned for

Maintain:
- beam
- terminals


Each iteration:
 1. Drain current iterator if present, otherwise continue
 2. Expand each program in the beam with simple terminal extensions
 3. Replace the beam with the N-best programs
 4. Set the current iterator to the N-best programs

=#

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
- The beam never contains duplicate programs
- Adding programs is O(1)
- Once no more programs will be added to the beam, it can be concretized (O(n log n)) to efficiently iterate over the beam in order O(n)

""" BeamIterator


"""
    $(TYPEDEF)

Describes an entry in a [`beam`](@ref).
Holds the program and its associated cost.
"""
struct BeamEntry
    program::RuleNode
    cost::Number
end

"""
    Base.isless(a::BeamEntry, b::BeamEntry)

Compares two BeamEntry's based on their associated costs.
"""
Base.isless(a::BeamEntry, b::BeamEntry) = a.cost < b.cost

"""
   struct Beam

A beam that contains at most N programs, only keeping the best.
One can push programs to a beam and this object ensures that the best N unique programs are kept.
Once a beam is completed, one can concretize it in order to efficiently iterate over the programs in order of increasing cost

This struct contains:
- Beam size: the maximum number of programs in the beam
- Heuristic cost function: given a program, computes its associated cost
- Program heap: contains the program, ensuring that the highest cost can be obtained efficiently
- Program set: a set representation of all the programs in the heap, ensuring that membership can be tested efficiently to make the beam's program unique
- Sorted program: can be created once the beam is such that we can iterate over program in order of increasing cost

Note that before concretization the sorted program list is set to nothing, and after concretization the program heap is set to nothing.
After concretization no programs can be added to the beam.
"""
mutable struct Beam
    beam_size::Number
    program_to_cost::Function
    programs::Union{MutableBinaryMaxHeap{BeamEntry},Nothing}
    program_set::Set{RuleNode}
    sorted_programs::Union{Vector{BeamEntry},Nothing}
end

"""
    Beam(beam_size::Number, program_to_cost::Function)

Creates a new empty beam given its size and heuristic cost function.
"""
Beam(beam_size::Number, program_to_cost::Function) = Beam(beam_size, program_to_cost, MutableBinaryMaxHeap{BeamEntry}(), Set{RuleNode}(), nothing)

"""
    clear!(beam::Beam)

Resets the beam, removing all programs from it. 
"""
function clear!(beam::Beam)
    beam.programs = MutableBinaryMaxHeap{BeamEntry}()
    beam.program_set = Set()
    beam.sorted_programs = nothing
end

"""
    Base.push!(beam::Beam, program::RuleNode)

Adds a program to the beam, ensuring that the beam size is not exceeded and only the best program is kept.
"""
function Base.push!(beam::Beam, program::RuleNode)
    # If the program heap is nothing, the beam has been concretized
    # This ensures that no programs are pushed to a concretized beam
    @assert !isnothing(beam.programs)

    # Abort of the beam already contains this program
    if program in beam.program_set
        return
    end

    cost = beam.program_to_cost(program)
    beam_entry = BeamEntry(program, cost)

    # If the beam has not been filled yet, add the program to the beam
    if length(beam.programs) < beam.beam_size
        push!(beam.programs, beam_entry)
        push!(beam.program_set, program)

    # Otherwise, check if the new program is better than the worst program in the beam
    elseif cost < first(beam.programs).cost
        # In that case, remove the worst program from the beam and add the new program
        removed = pop!(beam.programs)
        delete!(beam.program_set, removed.program)

        push!(beam.programs, beam_entry)
        push!(beam.program_set, program)
    end
end

"""
    concretize!(beam::Beam)

Makes the beam concrete by filling the sorted_programs list such that one can iterate of the beam in order of increasing cost efficiently.
Note that after concretization no more programs can be added to the beam.
"""
function concretize!(beam::Beam)
    beam.sorted_programs = extract_all_rev!(beam.programs)
    beam.programs = nothing
end

#=
    @programiterator BeamIterator(...)

A BeamIterator is constructed by providing the beam size and heuristic cost function.
Two beams are maintained:
- One dynamically containing the N best program
- One statically containing all terminals to expand programs with
=#
@programiterator BeamIterator(
    beam_size::Int=Inf,
    program_to_cost::Function= _ -> 0,
    beam=Beam(beam_size, program_to_cost),
    terminals=Beam(Inf, _ -> 0),
) <: AbstractBeamIterator


"""
    mutable struct BeamState

The iterator state for a beam iterator only maintains a pointer to the list of programs in beam sorted on heuristic cost.
"""
mutable struct BeamState
    current_beam_index::Int
end

"""
    initialize!(iter::AbstractBeamIterator)

Initializes the beam iterator by finding all terminals, adding these to the terminal beam and adding the N best terminals as intial beam.
"""
function initialize!(iter::AbstractBeamIterator)
    grammar = get_grammar(iter.solver)

    # Iterate over each terminal rule
    for rule_idx in eachindex(grammar.isterminal)
        grammar.isterminal[rule_idx] || continue # skip non-terminals

        # Obtain the RuleNode and type
        prog = RuleNode(rule_idx)
        type = grammar.types[rule_idx]

        # Always push a terminal to the terminal beam
        push!(iter.terminals, prog)

        # If the type of the terminal is the starting symbol, also add it the initial beam
        if type == get_starting_symbol(iter.solver)
            push!(iter.beam, prog)
        end
    end

    # As both beams are completed, concretize them
    concretize!(iter.beam)
    concretize!(iter.terminals)
end

"""
    combine!(iter::AbstractBeamIterator)

Creates new programs by expanding all programs in the beam with all possible terminals.
Only selects the N best programs of these to create the new beam.
"""
function combine!(iter::AbstractBeamIterator)
    grammar = get_grammar(iter.solver)

    # Finds all nonterminal shapes to combine the beam and termianls with
    terminals_mask     = grammar.isterminal
    nonterminals_mask  = .~terminals_mask
    nonterminal_shapes = UniformHole.(partition(Hole(nonterminals_mask), grammar), ([],))

    # Computes whether a combination exceed the maximum depth or size
    is_feasible = function(children::Tuple{Vararg{BeamEntry}})
        children = [c.program for c in children]
        maximum(depth.(children)) < get_max_depth(iter) &&
        sum(length.(children)) < get_max_size(iter)
    end

    # Gives a BeamEntry's return type
    get_return_type(entry::BeamEntry) = grammar.types[get_rule(entry.program)]

    # Given the types of children, creates a filter to obtain well typed expressions
    is_well_typed = child_types -> (children -> child_types == get_return_type.(children))

    # Obtain the sorted programs from the beam and clear it for the new programs
    old_beam = iter.beam.sorted_programs
    clear!(iter.beam)

    # Iterate over all shapes to expand with and obtain their types, arity and type filter
    for shape in nonterminal_shapes
        child_types  = Tuple(grammar.childtypes[findfirst(shape.domain)])
        arity        = length(child_types)
        typed_filter = is_well_typed(child_types)

        # A program from the beam can in be one of the child positions
        for beam_index in 1:arity
            # Children only can be terminals, execpt for the position where we place programs from the beam
            potential_children = collect(Iterators.repeated(iter.terminals.sorted_programs, arity))
            potential_children[beam_index] = old_beam

            # Obtain all possible combinations that are well typed and feasible in the depth and size limit
            candidate_combinations = Iterators.product(potential_children...)
            candidate_combinations = Iterators.filter(typed_filter, candidate_combinations)
            candidate_combinations = Iterators.filter(is_feasible, candidate_combinations)

            # Iterate over all possible programs and add them to the beam
            for child_tuple in candidate_combinations
                for rule_idx in findall(shape.domain)
                    program = RuleNode(rule_idx, [c.program for c in child_tuple])
                    push!(iter.beam, program)
                end
            end
        end
    end

    # Expanding is done; the beam can be concretized
    concretize!(iter.beam)
end

"""
    Base.iterate(iter::AbstractBeamIterator)

The initial call to the iterator. Initializes the beams and iterator's state.
"""
function Base.iterate(iter::AbstractBeamIterator)
    initialize!(iter)

    return Base.iterate(
        iter,
        BeamState(1)
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
    # Check if all programs from the current beam have been returned
    if state.current_beam_index > length(iter.beam.sorted_programs)
        # If so, expand the current beam and reset the pointer
        combine!(iter)
        state.current_beam_index = 1
    end

    # If the beam is empty, the iterator is exhausted; kill it
    if isnothing(iter.beam.sorted_programs) || isempty(iter.beam.sorted_programs)
        return nothing
    end
    
    # Otherwise, obtain the next program, increment the pointer and return that program.
    next_program = iter.beam.sorted_programs[state.current_beam_index].program
    state.current_beam_index += 1

    return next_program, state
end
