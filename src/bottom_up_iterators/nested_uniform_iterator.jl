mutable struct NestedUniformIterator
    collection::Any
    state::Any
    root::UniformHole
    grammar::ContextSensitiveGrammar
    uniform_iterator::Union{Nothing, UniformIterator}
    uniform_trees::Vector{UniformHole}
end

function NestedUniformIterator(
    collection::Any,
    root::UniformHole,
    grammar::ContextSensitiveGrammar
)::NestedUniformIterator
    return NestedUniformIterator(collection, nothing, root, grammar, nothing, [])
end

function get_next_rulenode!(
    iter::NestedUniformIterator
)::Union{RuleNode, Nothing}
    next_rulenode::Union{StateHole, RuleNode, Nothing} = nothing
    if !isnothing(iter.uniform_iterator)
        next_rulenode = next_solution!(iter.uniform_iterator)
    end

    while isnothing(next_rulenode)
        uniform_iterator_result = _iterate(iter)
        # Check if there aren't any combinations left.
        if isnothing(uniform_iterator_result)
            return nothing
        end

        (uniform_tree_children, state) = uniform_iterator_result
        iter.state = state
        uniform_tree::UniformHole = _create_uniform_tree(iter.root, collect(uniform_tree_children))
        push!(iter.uniform_trees, uniform_tree)

        solver::UniformSolver = UniformSolver(iter.grammar, copy(uniform_tree))
        iter.uniform_iterator = UniformIterator(solver, nothing)

        next_rulenode = next_solution!(iter.uniform_iterator)
    end

    return freeze_state(next_rulenode)
end

function get_uniform_trees(iter::NestedUniformIterator)::Vector{UniformHole}
    return iter.uniform_trees
end

function _iterate(iter::NestedUniformIterator)
    if isnothing(iter.state)
        return iterate(iter.collection)
    end

    return iterate(iter.collection, iter.state)
end

function _create_uniform_tree(
    root::UniformHole,
    children::Vector{UniformHole}
)::UniformHole
    uniform_tree::UniformHole = copy(root)
    uniform_tree.children = children
    return uniform_tree
end
