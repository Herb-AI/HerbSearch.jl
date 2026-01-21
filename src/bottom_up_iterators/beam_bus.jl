abstract type AbstractBeamBottomUpIterator <: AbstractCostBasedBottomUpIterator end

@programiterator BeamBottomUpIterator(
    bank=MeasureHashedBank{Float64, RuleNode}(),
    max_cost::Float64=Inf,
    current_costs::Vector{Float64}=Float64[],
    program_to_outputs::Union{Nothing,Function} = nothing, # Must return Float64
) <: AbstractBeamBottomUpIterator


# -=-=-=-=-=-=-=-=-=-
# Note: I placed comments styled like this where I have made changes
# I have made a file `test.jl` in this folder with a small experimental grammar and heuristic function...
# -=-=-=-=-=-=-=-=-=-





# -=-=-=-=-=-=-=-=-=-
# Retrieves the RuleNode corresponding to the address and call a to be implemented heuristic cost function
# -=-=-=-=-=-=-=-=-=-
calc_measure(iter::BeamBottomUpIterator, a::CombineAddress) = heuristic_cost(iter, retrieve(iter, a))

# -=-=-=-=-=-=-=-=-=-
# Should be overloaded by the user
# -=-=-=-=-=-=-=-=-=-
heuristic_cost(iter::BeamBottomUpIterator, program::RuleNode) = error("Not implemented")

# -=-=-=-=-=-=-=-=-=-
# This is probably not the best way to circumvent the horizon...
# -=-=-=-=-=-=-=-=-=-
compute_new_horizon(iter::AbstractCostBasedBottomUpIterator) = -Inf

# -=-=-=-=-=-=-=-=-=-
# This method makes sure that the queue size stays under a limit (currently hard coded to 100).
# -=-=-=-=-=-=-=-=-=-
function add_to_queue(iter::AbstractBeamBottomUpIterator, state::GenericBUState, address, total_cost)
    # If the queue still has space left, simply enqueue
    if length(state.combinations) < 100
        enqueue!(state.combinations, address, total_cost)
    
    # Otherwise find the worst item and replace that if the new item is better
    else
        worst_address, worst_cost = nothing, -Inf

        for (a, c) in state.combinations
            if c > worst_cost
                worst_address = a
                worst_cost = c
            end
        end

        if total_cost < worst_cost
            delete!(state.combinations, worst_address)
            enqueue!(state.combinations, address, total_cost)
        end
    end
end

# -=-=-=-=-=-=-=-=-=-
# Copied the combine function from the costbased_bus to alter the meassure computation
# -=-=-=-=-=-=-=-=-=-
function combine(iter::AbstractBeamBottomUpIterator, state::GenericBUState)
    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)
    
    # advance horizons
    state.last_horizon = state.new_horizon
    new_h = compute_new_horizon(iter)

    # if no better horizon found, stick to old one
    if isfinite(new_h)
        state.new_horizon = min(new_h, get_measure_limit(iter))
    else
        state.new_horizon = state.last_horizon
    end

    # build an address list grouped by type (this is fast to reuse below)
    addrs_by_type = Dict{Symbol,Vector{AccessAddress}}()
    for T in get_types(bank)
        vs = Vector{AccessAddress}()
        for c in get_measures(bank, T)
            entries = get_entries(bank, T, c)
            @inbounds for i in eachindex(entries)
                e = entries[i]
                prog = get_program(e)
                push!(vs, AccessAddress{Float64}(
                    T, c, i,
                    depth(prog), length(prog),
                    is_new(e)
                ))
            end
        end
        addrs_by_type[T] = vs
    end

    # Define filters to apply over child_tuples
    # Stays within solver bounds
    is_feasible = function(children::Tuple{Vararg{AccessAddress}})
        maximum(depth.(children)) < get_max_depth(iter) &&
        sum(size.(children)) < get_max_size(iter)
    end
    # Uses the correct types
    is_well_typed = child_types -> (children -> child_types == get_return_type.(children))

    # must use at least one *new* program to progress the horizon
    any_new = child_tuple -> any(a -> a.new_shape, child_tuple)

    # All “shapes”, i.e., rule schemas we can combine children with
    terminals_mask     = grammar.isterminal
    nonterminals_mask  = .~terminals_mask
    nonterminal_shapes = UniformHole.(partition(Hole(nonterminals_mask), grammar), ([],))

    # Iterate over shapes
    for shape in nonterminal_shapes
        child_types  = Tuple(grammar.childtypes[findfirst(shape.domain)])
        arity     = length(child_types)

        typed_filter = is_well_typed(child_types) 

        child_lists = map(t -> get(addrs_by_type, t, Vector{AccessAddress}()), child_types)
        any(isempty, child_lists) && continue

        candidate_combinations = Iterators.product(child_lists...)
        candidate_combinations = Iterators.filter(typed_filter, candidate_combinations)
        candidate_combinations = Iterators.filter(is_feasible, candidate_combinations)
        candidate_combinations = Iterators.filter(any_new, candidate_combinations)

        # cartesian product over the child lists
        for child_tuple in candidate_combinations
            # Iterate over concrete rules within that shape
            for rule_idx in findall(shape.domain)
                # -=-=-=-=-=-=-=-=-=-
                # This is different from costbased_bus and directly calls the calc_measure function
                # -=-=-=-=-=-=-=-=-=-
                address = CombineAddress(rule_idx, child_tuple)
                total_cost = calc_measure(iter, address)
                total_cost > get_measure_limit(iter) && continue

                # -=-=-=-=-=-=-=-=-=-
                # This is different from costbased_bus and calls the add_to_queue function that keeps the queue size under a certain limit
                # -=-=-=-=-=-=-=-=-=-
                add_to_queue(iter, state, address, total_cost)

                for ch in child_tuple
                    if ch.new_shape
                        get_entries(bank, get_return_type(ch), get_measure(ch))[get_index(ch)].is_new = false
                    end
                end
            end
        end
    end

    return state.combinations, state
end

"""
        $(TYPEDSIGNATURES)

Add the `program` (the result of combining `program_combination`) to the bank of
the `iter`.

Return `true` if the `program` is added to the bank, and `false` otherwise.

This `add_to_bank!` checks for observational equivalence.  
"""
# -=-=-=-=-=-=-=-=-=-
# This is different from costbased_bus to keep the bank size under a certain limit
# You already posed that this is not correct as the terminals should always be kept in the bank...
# -=-=-=-=-=-=-=-=-=-
function add_to_bank!(iter::AbstractBeamBottomUpIterator, addr::CombineAddress, prog::AbstractRuleNode)
    total_cost = calc_measure(iter, addr)
    if total_cost > get_measure_limit(iter) || 
        depth(prog) >= get_max_depth(iter) || 
        length(prog) >= get_max_size(iter)
        return false
    end
    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)
    ret_T   = grammar.types[get_operator(addr)]

    # -=-=-=-=-=-=-=-=-=-
    # Here is the not so efficient implementation of limitting the bank
    # -=-=-=-=-=-=-=-=-=-
    if get_bank_size(iter) >= 20
        highest_sym, highest_m = find_highest_in_bank(iter)

        if total_cost > highest_m
            return true
        end

        delete!(inner_bank(bank)[highest_sym], highest_m)
    end

    # observational equivalence per return type
    if is_observationally_equivalent(iter, prog, ret_T)
        return false
    end

    push!(get_entries(bank, ret_T, total_cost), BankEntry{RuleNode}(prog, true))
    return true
end

# -=-=-=-=-=-=-=-=-=-
# Find the worst item in the bank
# Should be changed to ignore terminals
# -=-=-=-=-=-=-=-=-=-
function find_highest_in_bank(iter::AbstractBeamBottomUpIterator)
    bank = inner_bank(get_bank(iter))

    # Find highest in bank
    highest_sym = nothing
    highest_m   = nothing

    for (sym, inner) in bank
        isempty(inner) && continue

        m = maximum(keys(inner))
        if highest_m === nothing || m < highest_m
            highest_m   = m
            highest_sym = sym
        end
    end

    highest_sym === nothing && error("bank is empty")

    return (highest_sym, highest_m)
end

# -=-=-=-=-=-=-=-=-=-
# Helper function to compute the size of the bank
# Also not that efficient, but works for now...
# -=-=-=-=-=-=-=-=-=-
function get_bank_size(iter::AbstractBeamBottomUpIterator)
    bank = inner_bank(get_bank(iter))

    if length(bank) == 0
        return 0
    end

    return sum(
        length(vec)
        for inner in values(bank)
        for vec in values(inner)
    )
end