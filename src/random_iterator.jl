function rand_with_constraints!(solver::Solver,path::Vector{Int})
    skeleton = get_node_at_location(solver,path)
    grammar = get_grammar(solver)
    @info "The maximum depth is $(get_max_depth(solver) - length(path)). $(get_max_depth(solver))"
    return _rand_with_constraints!(skeleton,solver, Vector{Int}(), mindepth_map(grammar), get_max_depth(solver))
end

function _rand_with_constraints!(skeleton::RuleNode,solver::Solver,path::Vector{Int},dmap::AbstractVector{Int}, remaining_depth::Int=10) 
    @info "The depth RuleNode left: $remaining_depth"

    for (i,child) ∈ enumerate(skeleton.children)
        push!(path,i)
        _rand_with_constraints!(child,solver,path, dmap, remaining_depth - 1)
        pop!(path)
    end
    return get_tree(solver)
end

function _rand_with_constraints!(hole::Hole,solver::Solver,path::Vector{Int},dmap::AbstractVector{Int}, remaining_depth::Int=10) 
    @info "The depth hole left: $remaining_depth"

    # TODO : probabilistic grammars support
    filtered_rules = filter(r->dmap[r] ≤ remaining_depth, findall(hole.domain))
    state = save_state!(solver)

    @assert !isfilled(hole)

    shuffle!(filtered_rules)
    found_feasable = false
    for rule_index ∈ filtered_rules
        @info "Heyyy"
        @show get_tree(solver)
        # println("Hole domain: $(hole.domain), tree: $(get_tree(solver)), rule_index: $rule_index")
        remove_all_but!(solver,path,rule_index)
        @info "Heyyy 2"
        if isfeasible(solver)
            found_feasable = true
            break
        end
        load_state!(solver,state)
        state = save_state!(solver)
    end

    if !found_feasable
        error("rand with constraints failed because there are no feasible rules to use")
    end

    # println("Found tree: ", get_tree(solver))
    subtree = get_node_at_location(solver, path)
    for (i,child) ∈ enumerate(subtree.children)
        push!(path,i)
        _rand_with_constraints!(child,solver,path, dmap, remaining_depth - 1)
        pop!(path)
    end
    return get_tree(solver)
end


@programiterator RandomSearchIterator(
    path::Vector{Int} = Vector{Int}()
    # TODO: Maybe limit number of iterations
)

Base.IteratorSize(::RandomSearchIterator) = Base.SizeUnknown()
Base.eltype(::RandomSearchIterator) = RuleNode

function Base.iterate(iter::RandomSearchIterator)
    solver_state = save_state!(iter.solver)
    return rand_with_constraints!(iter.solver, iter.path), solver_state
end

function Base.iterate(iter::RandomSearchIterator, solver_state::SolverState)
    # println("Solver state is : $solver_state")
    load_state!(iter.solver, solver_state)
    solver_state = save_state!(iter.solver)
    return rand_with_constraints!(iter.solver, iter.path), solver_state
end