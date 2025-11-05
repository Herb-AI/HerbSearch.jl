"""
    $(TYPEDEF)

Abstract supertype for cost-ordered bottom-up iterators.
Concrete implementations are expected to provide at least:
- `get_bank(iter)`
- `get_solver(iter)` and `get_grammar(get_solver(iter))`
- storage for `max_cost`
"""
abstract type AbstractCostBasedBottomUpIterator <: BottomUpIterator end


@programiterator CostBasedBottomUpIterator(
    bank=CostBank(),
    max_cost::Float64=Inf,
    current_costs::Vector{Float64}=Float64[],
    program_to_outputs::Union{Nothing,Function} = nothing, # Must return Float64
) <: AbstractCostBasedBottomUpIterator

function CostBasedBottomUpIterator(solver; max_cost=Inf, program_to_outputs=nothing)
    grammar    = get_grammar(solver)
    rule_costs = get_costs(grammar)
    return CostBasedBottomUpIterator(solver;
        bank=CostBank(),
        max_cost=max_cost,
        current_costs=rule_costs,
        program_to_outputs=program_to_outputs,
    )
end

get_max_cost(iter::AbstractCostBasedBottomUpIterator) = iter.max_cost
get_rule_cost(iter::AbstractCostBasedBottomUpIterator, rule_idx::Int) = iter.current_costs[rule_idx]

# make the *generic* code think "measure = cost"
get_measure_limit(iter::AbstractCostBasedBottomUpIterator) = get_max_cost(iter)

get_costs(grammar::AbstractGrammar) = abs.(grammar.log_probabilities)


"""
    struct CostBank{C}

Bank keyed **first by type**, then by **cost**, storing concrete programs (`RuleNode`s).
"""
struct CostBank{C}
    bank::DefaultDict{Symbol,DefaultDict{C,Vector{BankEntry}}}
    # per return-type: SET of VECTORS OF UInt64 (wrapped)
    seen_outputs::DefaultDict{Symbol,Set{OutputSig}}

    function CostBank{C}() where {C}
        inner_bank = () -> DefaultDict{C,Vector{BankEntry}}(() -> BankEntry[])
        seen       = DefaultDict{Symbol,Set{OutputSig}}(() -> Set{OutputSig}())
        return new{C}(
            DefaultDict{Symbol,DefaultDict{C,Vector{BankEntry}}}(inner_bank),
            seen,
        )
    end
end

CostBank() = CostBank{Float64}()

"""
    $(TYPEDSIGNATURES)

Checks a program for observational equivalence by evaluating the program, hashing the outputs and checking them against the set of seen outputs. 
    
Returns true, if the program was seen already.
Returns false, if the program was not seen yet. Adds the output signature to the set of seen outputs in that case.
"""
function is_observational_equivalent(
    iter::AbstractCostBasedBottomUpIterator,
    program::RuleNode,
    rettype::Symbol
)
    f = iter.program_to_outputs
    f === nothing && return false # checking for observational equivalence is turned off

    outs_any = f(program)
    sig_vec  = _hash_outputs_to_u64vec(outs_any)
    wrapped = OutputSig(sig_vec) # Needed for set formulation

    bank = get_bank(iter)
    seen = get!(bank.seen_outputs, rettype, Set{OutputSig}())

    if wrapped in seen
        return true
    else
        push!(seen, wrapped)
        return false
    end
end

get_types(cb::CostBank) = keys(cb.bank)

get_costs(cb::CostBank, T::Symbol) = keys(cb.bank[T])

get_entries(cb::CostBank, T::Symbol, c) = cb.bank[T][c]

get_programs(cb::CostBank, T::Symbol, c) =
    (e.program for e in cb.bank[T][c]) |> collect

get_cost(a::AccessAddress) = get_measure(a)

retrieve(cb::CostBank, a::AccessAddress) = get_programs(cb, get_return_type(a), get_cost(a))[get_index(a)]

function populate_bank!(iter::AbstractCostBasedBottomUpIterator)
    grammar = get_grammar(iter.solver)
    bank = get_bank(iter)

    # seed terminals using add_to_bank!
    for rule_idx in eachindex(grammar.isterminal)
        grammar.isterminal[rule_idx] || continue # skip non-terminals

        prog = RuleNode(rule_idx)
        addr = CostCombineAddress{0}(rule_idx, ())  # terminal: no child addresses

        add_to_bank!(iter, addr, prog)
    end
    
    # collect initial window
    # Collect the *initial window* of addresses: every terminal we’ve just added.
    out  = AccessAddress[]
    for T in get_types(bank)
        for c in get_costs(bank, T)
            c <= get_measure_limit(iter) || continue
            entries = get_entries(bank, T, c)
            @inbounds for i in eachindex(entries)
                prog = entries[i].program
                push!(out, AccessAddress(
                    c,               # cost
                    T,               # type
                    i,               # index in that bucket
                    depth(prog),     # depth of *concrete* program
                    length(prog),    # size   of *concrete* program
                    true             # all terminals are "new"
                ))
            end
        end
    end
    return out
end

# the iterator already expects this:
get_bank(iter::AbstractCostBasedBottomUpIterator) = iter.bank

calc_measure(iter::AbstractCostBasedBottomUpIterator, a::AccessAddress) = get_cost(a)

calc_measure(iter::AbstractCostBasedBottomUpIterator, children::Tuple) = sum(get_cost, children, init=0)


"""
Address describing “apply rule `rule_idx` to these children”.
"""
struct CostCombineAddress{N} <: AbstractAddress
    rule_idx::Int
    addrs::NTuple{N,AccessAddress}
end

get_children(a::CostCombineAddress) = a.addrs
get_rule(a::CostCombineAddress) = a.rule_idx

# cost = rule_cost + children_cost
function calc_measure(iter::AbstractCostBasedBottomUpIterator,
                      a::CostCombineAddress)
    rule_c = get_rule_cost(iter, a.rule_idx)
    return rule_c + calc_measure(iter, get_children(a))
end

function retrieve(iter::AbstractCostBasedBottomUpIterator, a::CostCombineAddress)
    grammar = get_grammar(iter.solver)
    kids = [retrieve(iter, ch) for ch in get_children(a)]
    # again: tweak constructor name/arity if yours is different
    return RuleNode(a.rule_idx, kids)
end


add_to_bank!(::AbstractCostBasedBottomUpIterator, ::AccessAddress, ::AbstractRuleNode) = true

function add_to_bank!(iter::AbstractCostBasedBottomUpIterator, addr::CostCombineAddress, prog::AbstractRuleNode)
    total_cost = calc_measure(iter, addr)
    if total_cost > get_measure_limit(iter) || 
        depth(prog) >= get_max_depth(iter) || 
        length(prog) >= get_max_size(iter)
        return false
    end 
    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)
    ret_T   = grammar.types[addr.rule_idx]

    # observational equivalence per return type
    if is_observational_equivalent(iter, prog, ret_T)
        return false
    end

    push!(get_entries(bank, ret_T, total_cost), BankEntry(prog, true))
    return true
end

function compute_new_horizon(iter::AbstractCostBasedBottomUpIterator)
    bank = get_bank(iter)
    grammar = get_grammar(iter.solver)

    # 1) collect cheapest & cheapest-new per type
    min_cost_by_type     = Dict{Symbol, Float64}()
    min_new_cost_by_type = Dict{Symbol, Float64}()

    for T in get_types(bank)
        for c in get_costs(bank, T)
            entries = get_entries(bank, T, c)
            isempty(entries) && continue

            # cheapest existing
            min_cost_by_type[T] = min(get(min_cost_by_type, T, Inf), c)

            # cheapest *new* at this type
            if any(e -> e.is_new, entries)
                min_new_cost_by_type[T] = min(get(min_new_cost_by_type, T, Inf), c)
            end
        end
    end

    best = Inf

    # 2) for every nonterminal rule, try “one new child, the rest old”
    for rule_idx in eachindex(grammar.isterminal)

        grammar.isterminal[rule_idx] && continue   # skip terminals

        ret_T      = grammar.types[rule_idx]
        child_types   = grammar.childtypes[rule_idx]
        rule_cost  = get_rule_cost(iter, rule_idx)

        # we need *some* program for every child type
        all(t -> haskey(min_cost_by_type, t), child_types) || continue
        # ...and we need *at least one* child type that is new
        any(t -> haskey(min_new_cost_by_type, t), child_types) || continue

        for new_pos in eachindex(child_types)
            t_new = child_types[new_pos]
            haskey(min_new_cost_by_type, t_new) || continue

            # cost of this particular choice “child i is new”
            total = rule_cost
            for (i, ct) in pairs(child_types)
                if i == new_pos
                    total += min_new_cost_by_type[ct]
                else
                    total += min_cost_by_type[ct]
                end
            end

            best = min(best, total)
        end
    end

    return best
end

function combine(iter::AbstractCostBasedBottomUpIterator, state::GenericBUState)
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
    # @TODO This is an optional caching of rules.
    addrs_by_type = Dict{Symbol,Vector{AccessAddress}}()
    for T in get_types(bank)
        vs = AccessAddress[]
        for c in get_costs(bank, T)
            entries = get_entries(bank, T, c)
            @inbounds for i in eachindex(entries)
                e = entries[i]
                prog = e.program
                push!(vs, AccessAddress(
                    c, T, i,
                    depth(prog), length(prog),
                    e.is_new
                ))
            end
        end
        addrs_by_type[T] = vs
    end

    is_feasible = function(children::Tuple{Vararg{AccessAddress}})
        maximum(depth.(children)) < get_max_depth(iter) &&
        sum(size.(children)) < get_max_size(iter)
    end
    is_well_typed = child_types -> (children -> child_types == get_return_type.(children))

    any_new = child_tuple -> any(a -> a.new_shape, child_tuple)

    # @TODO do this by shape, so we don't have to iterate separately 
    for rule_idx in eachindex(grammar.isterminal)
        grammar.isterminal[rule_idx] && continue

        child_types  = Tuple(grammar.childtypes[rule_idx])
        arity     = length(child_types)
        rule_cost = get_rule_cost(iter, rule_idx)

        typed_filter = is_well_typed(child_types) 
    
        child_lists = map(t -> get(addrs_by_type, t, AccessAddress[]), child_types)
        any(isempty, child_lists) && continue

        candidate_combinations = Iterators.product(child_lists...)
        candidate_combinations = Iterators.filter(typed_filter, candidate_combinations)
        candidate_combinations = Iterators.filter(is_feasible, candidate_combinations)
        candidate_combinations = Iterators.filter(any_new, candidate_combinations)

        # cartesian product over the child lists
        for child_tuple in candidate_combinations
            # must use at least one *new* program to progress the horizon

            total_cost = rule_cost + sum(a -> get_cost(a), child_tuple)
            total_cost > get_measure_limit(iter) && continue

            enqueue!(state.combinations, CostCombineAddress(rule_idx, Tuple(child_tuple)), total_cost)

            for ch in child_tuple
                if ch.new_shape == true
                    get_entries(bank, get_return_type(ch), get_measure(ch))[get_index(ch)].is_new = false
                end
            end
        end
    end

    return state.combinations, state
end


function Base.iterate(iter::AbstractCostBasedBottomUpIterator, state::GenericBUState)
    # Drain current uniform iterator if present
    if !isnothing(state.current_uniform_iterator)
        next_solution = next_solution!(state.current_uniform_iterator)
        if isnothing(next_solution)
            state.current_uniform_iterator = nothing
        else
            return next_solution, state
        end
    end

    solver = get_solver(iter)

    next_program_address, new_state = get_next_program(iter, state)

    while !isnothing(next_program_address)
        program = retrieve(iter, next_program_address)

        if isnothing(program) 
            return nothing
        end

        if length(program) > 1
            keep = add_to_bank!(iter, next_program_address, program)
            expr = rulenode2expr(program, get_grammar(iter.solver))

            # if the horizon is set to max, but we encounter a program that we want to add to the bank, then we recompute the horizon.
            if keep && 
                (state.last_horizon == get_measure_limit(iter) || 
                state.new_horizon == typemax(typeof(get_measure_limit(iter))) ||
                state.new_horizon == Inf)
                state.new_horizon = compute_new_horizon(iter)
            end
        end


        if is_subdomain(program, state.starting_node)
            # Check for constraints in the grammar
            if all(HerbConstraints.check_tree(constraint, program) for constraint in get_grammar(get_solver(iter)).constraints)
                return program, new_state
            end
        end

        next_program_address, new_state = get_next_program(iter, new_state)
    end

    return nothing
end