mutable struct CrossProductIterator
    collection::Any #
    rule::Int       # current parent rule
    state::Any      
    next_program::Union{RuleNode, Nothing}
end

function CrossProductIterator(
    rulenode_combinations::RuleNodeCombinations
)::CrossProductIterator
    collection = Iterators.product(rulenode_combinations.children_lists...)
    rule = rulenode_combinations.rule
    rulenode_combination::Any, state = iterate(collection)                  # TODO change the type
    next_program = RuleNode(rule, collect(rulenode_combination))

    return CrossProductIterator(collection, rule, state, next_program)
end

function Base.iterate(
    iter::CrossProductIterator
)::Union{RuleNode, Nothing}
    returned_program = iter.next_program

    if !isnothing(returned_program)
        println("iter.collection, ", iter.collection)
        println("iter.state, ", iter.state)
        println("iter.collection[1] ", iter.collection[1])
        if isnothing(iter.collection) && iter.collection[1] === nothing
            println("HELLO FROM CROSS PRODUCT ITERATOR EMPTY THING")
            iter.next_program = RuleNode(iter.rule, Vector{RuleNode}())
        else
            println("HELLO FROM CROSS PRODUCT ITERATOR NOT")
            rulenode_combination::Any, iter.state = iterate(iter.collection, iter.state)
            iter.next_program = RuleNode(iter.rule, collect(rulenode_combination))
        end
    end

    return returned_program
end

Base.iterate(iter::CrossProductIterator, _) = iterate(iter) 