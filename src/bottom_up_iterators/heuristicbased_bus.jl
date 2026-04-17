abstract type AbstractHeuristicBasedBottomUpIterator <: AbstractCostBasedBottomUpIterator end


@programiterator HeuristicBasedBottomUpIterator(
    heuristic::Function,
    bank=CostBank(),
    max_cost::Float64=Inf,
    current_costs::Vector{Float64}=Float64[1,1,1,1]
) <: AbstractHeuristicBasedBottomUpIterator

function build_cost_cross_product(
    iter::AbstractHeuristicBasedBottomUpIterator,
    grammar::AbstractGrammar,
    tree::UniformHole)

    println("\nCalling build_cost_cross_product")

    current_costs = get_current_costs(iter)

    # 1) Collect per-axis options (indices) and their costs in preorder.
    option_indices = Vector{Vector{Int}}()
    option_costs   = Vector{Vector{Float64}}()

    function build_axes(node::UniformHole)
        idxs = findall(node.domain)
        push!(option_indices, idxs)
        push!(option_costs, @inbounds Float64.(view(current_costs, idxs)))
        @inbounds for child in node.children
            build_axes(child)
        end
    end
    build_axes(tree)

    axis_lengths = map(length, option_indices)
    n_axes = length(axis_lengths)

    # 2) Row-major strides: stride[k] = prod(axis_lengths[k+1:end]); stride[end] = 1
    strides = similar(axis_lengths)
    s = 1
    @inbounds for k in n_axes:-1:1
        strides[k] = s
        s *= axis_lengths[k]
    end
    total_len = s

    # 3) Fill flat totals with a recursive loop.
    totals_flat = Vector{Float64}(undef, total_len)

    function fill_axis(k::Int, running::Float64, base_lin::Int)
        if k > n_axes
            @inbounds totals_flat[base_lin] = running
            return
        end
        lenk    = axis_lengths[k]
        costs_k = option_costs[k]
        step    = strides[k]
        @inbounds for i in 1:lenk
            fill_axis(k + 1, running + costs_k[i], base_lin + (i - 1) * step)
        end
    end
    fill_axis(1, 0.0, 1)


    solver = get_solver(iter)
    uniform_solver = UniformSolver(grammar, tree, with_statistics=solver.statistics)
    iterator = UniformIterator(uniform_solver, iter)

    for (i, p) in enumerate(iterator)
        # @show p
        totals_flat[i] = iter.heuristic(p)
        
        # if i == 50
        #     throw("ellende")
        # end
    end

    @show totals_flat

    axis_lengths = map(length, option_indices)
    
    sorted_costs = sort(unique(totals_flat))
    return totals_flat, collect(axis_lengths), sorted_costs
end

function compute_new_horizon(iter::AbstractHeuristicBasedBottomUpIterator)
    println("Calling compute_new_horizon")

    bank    = get_bank(iter)
    grammar = get_grammar(iter.solver)
    limit   = get_measure_limit(iter)

    bytype = Dict{Symbol, Vector{UniformTreeEntry}}()
    for (_, ent) in bank.uh_index
        push!(get!(bytype, ent.rtype, UniformTreeEntry[]), ent)
    end

    terminals = grammar.isterminal
    nonterm   = .~terminals
    shapes    = UniformHole.(partition(Hole(nonterm), grammar), ([],))

    best = Inf

    for shape in shapes
        rule_idx = findfirst(shape.domain)
        rule_idx === nothing && continue
        child_types = Tuple(grammar.childtypes[rule_idx])

        candidate_lists = Vector{Vector{UniformTreeEntry}}(undef, length(child_types))
        feasible = true
        @inbounds for i in 1:length(child_types)
            lst = get(bytype, child_types[i], nothing)
            if lst === nothing || isempty(lst)
                feasible = false; break
            end
            candidate_lists[i] = lst
        end
        feasible || continue

        op_min = minimum(@view get_current_costs(iter)[shape.domain])

        for tuple_children in Iterators.product(candidate_lists...)
            any_new = any(e.new_shape for e in tuple_children)
            any_new || continue
            lb = op_min
            @inbounds for e in tuple_children
                lb += e.sorted_costs[1]
            end
            if lb < best && lb ≤ limit
                best = lb
            end
        end
    end

    return best
end