"""
    $(TYPEDEF)

Abstract supertype for cost-ordered bottom-up iterators.
Concrete implementations are expected to provide at least:
- `get_bank(iter)`
- `get_solver(iter)` and `get_grammar(get_solver(iter))`
- storage for `max_cost`
"""
abstract type AbstractCostBasedBottomUpIterator <: BottomUpIterator end

struct RuleCombineAddress{N} <: AbstractAddress
    rule
    addrs::NTuple{N,AccessAddress}
end

RuleCombineAddress(rule, addrs::AbstractVector{<:AccessAddress}) = RuleCombineAddress(rule, Tuple(addrs))

get_children(c::RuleCombineAddress) = c.addrs

get_operator(c::RuleCombineAddress) = c.rule.ind

get_combine_rule(c::RuleCombineAddress) = c.rule

@programiterator CostBasedBottomUpIterator(
    bank=MeasureHashedBank{Float64, RuleNode}(),
    max_cost::Float64=Inf,
    current_costs::Vector{Float64}=Float64[],
    program_to_outputs::Union{Nothing,Function} = nothing, # Must return Float64
    combine_operators::Set{Tuple{RuleNode, Vector{UniformHole}}} = Set{Tuple{RuleNode, Vector{UniformHole}}}(), # TODO: remove, this is used for initializaiton and because I will add custom combine rules
    combinators::Dict{Tuple{Vararg{Symbol}}, Vector{RuleNode}} = Dict{Tuple{Vararg{Symbol}}, Vector{RuleNode}}()  # A vector of (combine_tree, shapes_of_children)
    ) <: AbstractCostBasedBottomUpIterator

@doc """
    CostBasedBottomUpIterator

A bottom-up iterator which enumerates program by increasing cost.

The bank is ordered by measures, i.e., the cost, just like the shape-based BUS but of type `Float64`.
In contrast to the shape-based BUS implementations, each `BankEntry` holds a single program, not a shape. While is worse for propagating constraints, this is significantly faster for checking observational equivalence. 

In `CostBasedBottomUpIterator`, we assume the costs to be compositional, i.e., the cost of a program is the sum of the costs of the sub-rules. This also holds when constructing a new program as the combination of existing programs in the bank.

`CostBasedBottomUpIterator` implements and propagates observational equivalence by default. 
To enable provide a `program_to_outputs` function, which takes a `RuleNode` and returns a concrete program. To check for observational equivalence, the outputs are hashed, compared to the bank of seen outputs, and added if not seen before.

`CostBasedBottomUpIterator` keeps an enumeration window, similar to `BottomUpIterator`. 
""" CostBasedBottomUpIterator



"""
    $(TYPEDSIGNATURES)

Given an iter and the rule index, returns the current cost of that index, by getting the respective element of current_costs.
"""
get_rule_cost(iter::AbstractCostBasedBottomUpIterator, rule_idx::Int) = iter.current_costs[rule_idx]

"""
    $(TYPEDSIGNATURES)

Returns maximum cost, which is set at init. If not defined, the maximum cost is set to `Inf`.
"""
get_measure_limit(iter::AbstractCostBasedBottomUpIterator) = iter.max_cost

get_costs(grammar::AbstractGrammar) = abs.(grammar.log_probabilities)

get_combinators(iter::AbstractCostBasedBottomUpIterator) = iter.combinators

get_combine_operators(iter::AbstractCostBasedBottomUpIterator) = iter.combine_operators

function add_new_terminals!(iter::AbstractCostBasedBottomUpIterator, new_terminals::Vector{<:AbstractRuleNode}, costs::Vector{Float64})
    grammar = get_grammar(iter)
    for i in eachindex(new_terminals)
        rn = new_terminals[i]
        cost = costs[i]
        ret_T = return_type(grammar, rn)
        # some terminals may have holes. Split them to turn terminals into specific trees of the grammar
        split_terminals = HerbSearch.split_hole(rn, grammar)
        for new_term in split_terminals
            if !is_observationally_equivalent(iter, new_term, ret_T)
                be = BankEntry(new_term, true)
                push!(get_entries(iter.bank, ret_T, cost), be)
            end
        end
    end    
end

"""
$(TYPEDSIGNATURES)
"""
function add_combinators!(
    iter::AbstractCostBasedBottomUpIterator, 
    new_combinators::Vector{<:AbstractRuleNode}
    )
    """
    gets holes on leaves to establish types of children of the new combinator
    """
    function _get_holes(rn::AbstractRuleNode, res::Vector{UniformHole})
        @match rn begin
            ::UniformHole && if isempty(HerbCore.get_children(rn)) end => push!(res, deepcopy(rn)) #leaf hole
            ::UniformHole => for ch in HerbCore.get_children(rn) 
                _get_holes(ch, res)
            end
            ::RuleNode => for ch in HerbCore.get_children(rn) 
                _get_holes(ch, res)
            end
        end
    end
    grammar = get_grammar(iter)
    comb_ops = get_combine_operators(iter)
    for rn in new_combinators
        holes = Vector{UniformHole}()
        _get_holes(rn, holes)
        # combinators may contain holes at any level, not only leaf.
        # if that is the case, split them into combinators for each possible configuration of those holes.
        split_combs = _split_hole(rn, grammar)
        foreach(new_comb -> push!(comb_ops, (new_comb, holes)), split_combs)
    end
    populate_combinators!(iter)
end

"""
copied from compression_ext, but does not split terminal holes.
"""
function _split_hole(rule::RuleNode, g)
    isempty(rule.children) && return [rule]
    splits = []
    children_res = [_split_hole(ch, g) for ch in rule.children]
    for children in Iterators.product(children_res...)
        new_rule = RuleNode(get_rule(rule), collect(deepcopy(children)))
        push!(splits, new_rule)
    end
    return splits
end

"""
copied from compression_ext, but does not split terminal holes.
"""
function _split_hole(hole::UniformHole, g)
    isempty(HerbCore.get_children(hole)) && return [hole]
    splits = []
    isfilled(hole) && return [hole]
    children_res = [_split_hole(ch, g) for ch in hole.children]
    for (i, d) in enumerate(hole.domain)
        d || continue
        for children in Iterators.product(children_res...)
            new_rule = RuleNode(i, collect(deepcopy(children)))
            push!(splits, new_rule)
        end
    end
    return splits
end

"""
    $(TYPEDSIGNATURES)

Checks a program for observational equivalence by evaluating the program, hashing the outputs and checking them against the set of seen outputs. 
    
Returns true, if the program was seen already.
Returns false, if the program was not seen yet. Adds the output signature to the set of seen outputs in that case.
"""
function is_observationally_equivalent(
    iter::AbstractCostBasedBottomUpIterator,
    program::RuleNode,
    rettype::Symbol
)
    fn_map_to_outputs = iter.program_to_outputs
    if isnothing(fn_map_to_outputs)
        return false # no function given for observational equivalence, assume not equivalent
    end
    outputs = fn_map_to_outputs(program)
    outputs = hash(outputs, HASH_SEED)

    bank = get_bank(iter)
    observed = get!(observed_outputs(bank), rettype, Set{UInt64}())

    if outputs in observed
        return true
    else
        push!(observed, outputs)
        return false
    end
end


"""
    $(TYPEDSIGNATURES)

Fill the bank with the concrete programs in the grammar, i.e., the terminals.
Returns the [`AccessAddress`](@ref)es of the newly-added programs.
"""
function populate_bank!(iter::AbstractCostBasedBottomUpIterator)
    grammar = get_grammar(iter)
    bank = get_bank(iter)

    # seed terminals using add_to_bank!
    for rule_idx in eachindex(grammar.isterminal)
        grammar.isterminal[rule_idx] || continue # skip non-terminals

        prog = RuleNode(rule_idx)
        # checking it here too because we may have refactored some of the terminals already
        # is_observationally_equivalent(iter, prog, HerbGrammar.return_type(grammar, rule_idx)) && continue
        addr = CombineAddress{0}(rule_idx, ())  # terminal: no child addresses

        add_to_bank!(iter, addr, prog)
    end
    
    # collect initial window
    # Collect the *initial window* of addresses: every terminal we’ve just added.
    out  = AccessAddress[]
    for T in get_types(bank)
        for c in get_measures(bank, T)
            c <= get_measure_limit(iter) || continue
            @inbounds for (i,prog) in enumerate(get_programs(bank,T,c))
                push!(out, AccessAddress{Float64}(
                    T,               # type
                    c,               # cost
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

function populate_combinators!(iter::AbstractCostBasedBottomUpIterator)
    
    grammar = get_grammar(iter)
    # add grammar nonterminals to combine operators.
    combine_operators = get_combine_operators(iter)

    for rule_idx in eachindex(grammar.isterminal)
        grammar.isterminal[rule_idx] && continue # skip terminals
        child_types = HerbGrammar.child_types(grammar, rule_idx)
        children = [UniformHole(grammar.types .== cht) for cht in child_types]
        push!(combine_operators, (RuleNode(rule_idx, children), children))
    end

    # make a dictionary {children_shapes : combine operators}
    combinators = get_combinators(iter)
    # empty combinators in case they are being redefined.
    empty!(combinators)
    for (rule, children) in combine_operators
        push!(get!(combinators, Tuple(HerbGrammar.return_type(grammar, ch) for ch in children), RuleNode[]), rule)
    end
end

"""
        $(TYPEDSIGNATURES)

Initial call of the bottom-up iterator.

Populate the bank with initial programs and populate combinators with nonterminal rules.

Return the first program and a state-tracking [`GenericBUState`](@ref) containing the
remaining initial programs and the initialstate for the `combine` function
"""
function Base.iterate(iter::AbstractCostBasedBottomUpIterator)
    solver = get_solver(iter)
    starting_node = deepcopy(get_tree(solver))

    populate_combinators!(iter)
    # Populate bank with terminals and get their AccessAddresses
    addrs = populate_bank!(iter)


    # Priority queue keyed by address, prioritized by its measure
    pq = PriorityQueue{AbstractAddress, Number}(DataStructures.FasterForward())
    for acc in addrs
        push!(pq, acc => get_measure(acc))
    end

    return Base.iterate(
        iter,
        GenericBUState(
            pq,
            init_combine_structure(iter),
            nothing,
            starting_node,
            -Inf, # last_horizon
            0 # new_horizon
        )
    )
end

"""
    $(TYPEDSIGNATURES)

Given the children of a node, returns the accumulated cost of the children, i.e., the sum of their respective costs.
"""
_calc_measure(iter::AbstractCostBasedBottomUpIterator, children::Tuple) = sum(get_measure, children, init=0)

"""
    $(TYPEDSIGNATURES)

Calculates the cost of a CombineAddress, which refers to a concrete program. 
"""
function calc_measure(iter::AbstractCostBasedBottomUpIterator,
                      a::CombineAddress)
    rule_c = get_rule_cost(iter, get_operator(a))
    return rule_c + _calc_measure(iter, get_children(a))
end

"""
    $(TYPEDSIGNATURES)

Calculates the cost of a RuleCombineAddress. Here cost of a combinator is cost of its root. 
"""
function calc_measure(iter::AbstractCostBasedBottomUpIterator,
                      a::RuleCombineAddress)
    rule_c = get_rule_cost(iter, get_operator(a))
    return rule_c + _calc_measure(iter, get_children(a))
end

"""
    $(TYPEDSIGNATURES)

Calculates the cost of a CombineAddress given a concrete program in form of a `RuleNode`.
"""
calc_measure(iter::AbstractCostBasedBottomUpIterator, rn::AbstractRuleNode) = abs(HerbGrammar.rulenode_log_probability(rn, HerbConstraints.get_grammar(iter)))

"""
    $(TYPEDSIGNATURES)

Retrieve a program using a CombineAddress. Overwrites the parent function, as AbstractCostBasedBottomUpIterator operates over concrete trees, not uniform trees.
"""
function retrieve(iter::AbstractCostBasedBottomUpIterator, a::CombineAddress)
    kids = [retrieve(iter, ch) for ch in get_children(a)]
    return RuleNode(get_operator(a), kids)
end

"""
    $(TYPEDSIGNATURES)

Retrieve a program using a CombineAddress. Overwrites the parent function, as AbstractCostBasedBottomUpIterator operates over concrete trees, not uniform trees.
"""
function retrieve(iter::AbstractCostBasedBottomUpIterator, a::RuleCombineAddress)

    function retrieve_helper!(combine_rule::AbstractRuleNode, kids::Vector{RuleNode})
        children = HerbCore.get_children(combine_rule)
        for i in eachindex(children)
            @match children[i] begin
                ::RuleNode => retrieve_helper!(children[i], kids)
                ::UniformHole => begin
                    cur[] += 1
                    cur_child = kids[cur[]]
                    children[i] = cur_child
                end
            end
        end
    end
    
    combine_rule = get_combine_rule(a)
    combine_rule = deepcopy(combine_rule)
    kids = [retrieve(iter, ch) for ch in get_children(a)]
    cur = Ref(0)
    retrieve_helper!(combine_rule, kids)
    return combine_rule
end


"""
        $(TYPEDSIGNATURES)

Add the `program` (the result of combining `program_combination`) to the bank of
the `iter`.

Return `true` if the `program` is added to the bank, and `false` otherwise.

This `add_to_bank!` checks for observational equivalence.  
"""
function add_to_bank!(iter::AbstractCostBasedBottomUpIterator, addr::RuleCombineAddress, prog::AbstractRuleNode)
    total_cost = calc_measure(iter, addr)
    if total_cost > get_measure_limit(iter) || 
        depth(prog) >= get_max_depth(iter) || 
        length(prog) >= get_max_size(iter)
        return false
    end 
    bank    = get_bank(iter)
    grammar = get_grammar(iter)
    ret_T   = grammar.types[get_operator(addr)]

    # observational equivalence per return type
    if is_observationally_equivalent(iter, prog, ret_T)
        return false
    end

    push!(get_entries(bank, ret_T, total_cost), BankEntry{RuleNode}(prog, true))
    return true
end

"""
        $(TYPEDSIGNATURES)

Add the `program` (the result of combining `program_combination`) to the bank of
the `iter`.

Return `true` if the `program` is added to the bank, and `false` otherwise.

This `add_to_bank!` checks for observational equivalence.  
"""
function add_to_bank!(iter::AbstractCostBasedBottomUpIterator, addr::CombineAddress, prog::AbstractRuleNode)
    total_cost = calc_measure(iter, addr)
    if total_cost > get_measure_limit(iter) || 
        depth(prog) >= get_max_depth(iter) || 
        length(prog) >= get_max_size(iter)
        return false
    end 
    bank    = get_bank(iter)
    grammar = get_grammar(iter)
    ret_T   = grammar.types[get_operator(addr)]

    # observational equivalence per return type
    if is_observationally_equivalent(iter, prog, ret_T)
        return false
    end

    push!(get_entries(bank, ret_T, total_cost), BankEntry{RuleNode}(prog, true))
    return true
end


"""
$(TYPEDSIGNATURES)


Compute the **new horizon**  using the current contents of the bank.
The new_horizon is an exclusive upper bound on the window we currently try to enumerate, with the inclusive lower bound being the last_horizon. 
Both are stored in the `BottomUpState`.

Definition:
- Consider all **non-terminal shapes** (operators).
- For each shape, form the cheapest child tuple that uses
**at least one `new` child** (as marked by the bank’s `is_new` flags) and all other
children at their **cheapest existing** measures (per return type).
- The next horizon is the minimum, over those shapes, of
`operator_cost + _calc_measure(children_tuple)`.

Note that this differs from `compute_new_horizon(iter::BottomUpIterator)`, as operate over singular programs, not shapes.

Notes:
- “Newness” is derived from the bank’s `is_new` flags on entries, **not** from horizons.
- This function does **not** mutate the bank or the state (other than reading state).
"""
function compute_new_horizon(iter::AbstractCostBasedBottomUpIterator)
    bank = get_bank(iter)
    grammar = get_grammar(iter)

    # 1) collect cheapest & cheapest-new per type
    min_cost_by_type     = Dict{Symbol, Float64}()
    min_new_cost_by_type = Dict{Symbol, Float64}()

    for T in get_types(bank)
        for c in get_measures(bank, T)
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

    # for rule_idx in eachindex(grammar.isterminal)
    # for rule_idx in eachindex(grammar.isterminal)
    combinators = get_combinators(iter)
    for (child_types, combinator_rules) in combinators

        ret_T = grammar.types[[cr.ind for cr in combinator_rules]]

        # we need *some* program for every child type
        all(t -> haskey(min_cost_by_type, t), child_types) || continue
        # ...and we need *at least one* child type that is new
        any(t -> haskey(min_new_cost_by_type, t), child_types) || continue

        for new_pos in eachindex(child_types)
            t_new = child_types[new_pos]
            haskey(min_new_cost_by_type, t_new) || continue
            
            for rule in combinator_rules
                rule_idx = rule.ind
                rule_cost  = get_rule_cost(iter, rule_idx)

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
    end

    return best
end



"""
    $(TYPEDSIGNATURES)

Combine the programs currently in `iter`'s bank to create a new set of programs.
Constructs all tuples of combinations of programs joined by an operator. 
To ensure that we only consider new programs, the tuple of existing programs has to contain at least one **new** program.
New programs are represented by `CombineAddress`es, i.e., operators over a tuple of existing programs, represented with `AccessAddress`.

Combine also calculates the new enumeration window, i.e. sets last_horizon to new_horizon and calculates new_horizon via `compute_new_horizon`.
Enqueues ALL found combinations into `state.combinations` that are bigger than last_horizon, but will NOT prune solutions that exceed the current window, i.e., new_horizon.
"""
function combine(iter::AbstractCostBasedBottomUpIterator, state::GenericBUState)
    bank    = get_bank(iter)
    grammar = get_grammar(iter)
    
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

    combinators = get_combinators(iter)

    # Iterate over combinators grouped by shapes
    for (child_types, combinator_rules) in combinators

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
            for rule in combinator_rules
                rule_idx = rule.ind
                rule_cost = get_rule_cost(iter, rule_idx)

                total_cost = rule_cost + sum(a -> get_measure(a), child_tuple)
                total_cost > get_measure_limit(iter) && continue

                push!(state.combinations, RuleCombineAddress(rule, child_tuple) => total_cost)

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