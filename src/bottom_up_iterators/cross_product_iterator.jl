mutable struct CrossProductIterator
    collection::Any
    rule::Int
    state::Any
    next_program::Union{RuleNode, Nothing}
end

function CrossProductIterator(rulenode_combinations::RuleNodeCombinations)
    collection = Iterators.product(rulenode_combinations.children_lists...)
    rule = rulenode_combinations.rule
    rulenode_combination::RuleNodeCombinations, state = iterate(collection)
    next_program = RuleNode(rule, collect(rulenode_combination))

    return CrossProductIterator(collection, rule, state, next_program)
end

function Base.iterate(iter::CrossProductIterator)::Union{RuleNode, Nothing}
    returned_program = iter.next_program

    if !isnothing(returned_program)
        rulenode_combination::RuleNodeCombinations, iter.state = iterate(iter.collection, iter.state)
        iter.next_program = RuleNode(rule, collect(rulenode_combination))
    end

    return returned_program
end

Base.iterate(iter::CrossProductIterator, _) = iterate(iter) 