using DataStructures: DefaultDict

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
    current_costs::Vector{Float64}=Float64[]
) <: AbstractCostBasedBottomUpIterator


function CostBasedBottomUpIterator(solver; max_cost=Inf)
    grammar = get_grammar(solver)
    # take abs(log p) as a cost, like you suggested
    rule_costs = Float64.(abs.(grammar.log_probabilities))
    return CostBasedBottomUpIterator(solver;
        bank=CostBank(),
        max_cost=max_cost,
        current_costs=rule_costs,
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
    function CostBank{C}() where {C}
        inner = () -> DefaultDict{C,Vector{BankEntry}}(() -> BankEntry[])
        return new{C}(DefaultDict{Symbol,DefaultDict{C,Vector{BankEntry}}}(inner))
    end
end

# nice default: Float64 costs
CostBank() = CostBank{Float64}()

get_types(cb::CostBank) = keys(cb.bank)

get_costs(cb::CostBank, T::Symbol) = keys(cb.bank[T])

get_entries(cb::CostBank, T::Symbol, c) = cb.bank[T][c]

get_programs(cb::CostBank, T::Symbol, c) =
    (e.program for e in cb.bank[T][c]) |> collect

get_cost(a::AccessAddress) = get_measure(a)

retrieve(cb::CostBank, a::AccessAddress) = get_programs(cb, get_return_type(a), get_cost(a))[get_index(a)]

function populate_bank!(iter::AbstractCostBasedBottomUpIterator)
    grammar = get_grammar(iter.solver)
    bank    = get_bank(iter)

    # seed terminals
    # Create concrete terminal programs from the grammar and put them in the bank.
    for rule_idx in eachindex(grammar.isterminal)
        grammar.isterminal[rule_idx] || continue

        ret_type   = grammar.types[rule_idx]
        rule_cost  = get_rule_cost(iter, rule_idx)
        rule_cost <= get_max_cost(iter) || continue

        # adjust if your RuleNode signature differs
        terminal_prog = RuleNode(rule_idx, AbstractRuleNode[])

        push!(get_entries(bank, ret_type, rule_cost), BankEntry(terminal_prog, true))
    end
    
    # collect initial window
    # Collect the *initial window* of addresses: every terminal we’ve just added.
    out  = AccessAddress[]
    for T in get_types(bank)
        for c in get_costs(bank, T)
            c <= get_max_cost(iter) || continue
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

calc_measure(iter::AbstractCostBasedBottomUpIterator, children::Tuple) =
    sum(get_cost, children)


"""
Address describing “apply rule `rule_idx` to these children”.
"""
struct CostCombineAddress{N} <: AbstractAddress
    rule_idx::Int
    addrs::NTuple{N,AccessAddress}
end

get_children(a::CostCombineAddress) = a.addrs
get_rule(a::CostCombineAddress)     = a.rule_idx

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

function retrieve(iter::AbstractCostBasedBottomUpIterator,
                  a::AccessAddress)::AbstractRuleNode
    retrieve(get_bank(iter), a)
end

add_to_bank!(::AbstractCostBasedBottomUpIterator, ::AccessAddress, ::AbstractRuleNode) = true

function add_to_bank!(iter::AbstractCostBasedBottomUpIterator, addr::CostCombineAddress, prog::AbstractRuleNode)
    total_cost = calc_measure(iter, addr)
    if total_cost > get_max_cost(iter) || 
        depth(prog) >= get_max_depth(iter) || 
        length(prog) >= get_max_size(iter)
        return false
    end 
    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)
    ret_T   = grammar.types[addr.rule_idx]

    push!(get_entries(bank, ret_T, total_cost), BankEntry(prog, true))
    return true
end

function compute_new_horizon(iter::AbstractCostBasedBottomUpIterator)
    bank    = get_bank(iter)
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
    # @TODO Check whether this is correct
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
    @show state.last_horizon, new_h
    
    # if no better horizon found, stick to old one
    if isfinite(new_h)
        state.new_horizon = min(new_h, get_max_cost(iter))
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

        # cartesian product over the child lists
        for child_tuple in candidate_combinations
            # must use at least one *new* program to progress the horizon
            any_new = any(a -> a.new_shape, child_tuple)
            any_new || continue

            total_cost = rule_cost + sum(a -> get_cost(a), child_tuple)
            total_cost > get_measure_limit(iter) && continue

            enqueue!(state.combinations, CostCombineAddress(rule_idx, Tuple(child_tuple)), total_cost)
        end
    end

    # sort all candidates by cost *before* putting them in the PQ
    # @TODO is this necessary?
    # sort!(candidates, by = first)

    # @show length(state.combinations), peek(state.combinations)[2]

    # after we created wave-k parents, old newness is consumed
    for T in get_types(bank)
        for c in get_costs(bank, T)
            for entry in get_entries(bank, T, c)
                entry.is_new = false
            end
        end
    end

    return state.combinations, state
end
