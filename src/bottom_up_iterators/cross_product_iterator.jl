mutable struct CrossProductIterator
    root::AbstractRuleNode
    iterable::Any
    iteration_result::Any
end

function CrossProductIterator(
    rulenode_combinations::RuleNodeCombinations
)::CrossProductIterator
    root = rulenode_combinations.root

    # Initialize `iterable` for the case when `root` is terminal.
    iterable = [Tuple{}()]

    # Initialize `iterable` correctly when `root` is nonterminal.
    if !isempty(rulenode_combinations.children_lists)
        iterable = Iterators.product(rulenode_combinations.children_lists...)
    end

    iteration_result = iterate(iterable)
    return CrossProductIterator(root, iterable, iteration_result)
end

function Base.iterate(
    iter::CrossProductIterator
)::Union{AbstractRuleNode, Nothing}
    if isnothing(iter.iteration_result)
        return nothing
    end

    children, state = iter.iteration_result
    iter.iteration_result = iterate(iter.iterable, state)

    program::AbstractRuleNode = copy(iter.root) 
    program.children = collect(children)
    return program
end

Base.iterate(iter::CrossProductIterator, _) = iterate(iter) 