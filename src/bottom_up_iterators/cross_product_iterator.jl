mutable struct CrossProductIterator
    rule::Int
    iterable::Any
    iteration_result::Any
end

function CrossProductIterator(
    rulenode_combinations::RuleNodeCombinations
)::CrossProductIterator
    rule = rulenode_combinations.rule

    # Initialize `iterable` for the case when `rule` is terminal.
    iterable = [Tuple{}()]

    # Initialize `iterable` correctly when `rule` is nonterminal.
    if !isempty(rulenode_combinations.children_lists)
        iterable = Iterators.product(rulenode_combinations.children_lists...)
    end

    iteration_result = iterate(iterable)
    return CrossProductIterator(rule, iterable, iteration_result)
end

function Base.iterate(
    iter::CrossProductIterator
)::Union{RuleNode, Nothing}
    if isnothing(iter.iteration_result)
        return nothing
    end

    children, state = iter.iteration_result
    iter.iteration_result = iterate(iter.iterable, state)

    return RuleNode(iter.rule, collect(children))
end

Base.iterate(iter::CrossProductIterator, _) = iterate(iter) 