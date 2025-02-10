"""
    mutable struct NestedRulenodeIterator

Iterator abstraction used by `BottomUpIterators`. It encapsulates the following:
* `collection::Any`: Iterable which yields collections of `RuleNodes`. The returned `RuleNodes` should be combined to create new programs.
* `state::Any`: Internal state passed to the `iterate` function.
* `rule::Int`: Index of the rule combining the returned `RuleNodes`.
"""

mutable struct NestedRulenodeIterator
    collection::Any
    state::Any
    rule::Int
end

"""
    NestedRulenodeIterator()::NestedRulenodeIterator

Created an empty `NestedRulenodeIterator` (i.e. No `RuleNodes` are created.).
"""
NestedRulenodeIterator()::NestedRulenodeIterator = NestedRulenodeIterator([], nothing, -1)

"""
    NestedRulenodeIterator(collection::Any, rule::Int)::NestedRulenodeIterator

Create a `NestedRulenodeIterator` iterating over the given `collection` and combining the collections of `RuleNodes` using the given `rule`.
"""
NestedRulenodeIterator(collection::Any, rule::Int)::NestedRulenodeIterator = NestedRulenodeIterator(collection, nothing, rule)

"""
    function get_next_rulenode!(nested_rulenode_iterator::NestedRulenodeIterator)::Union{RuleNode, Nothing}

Generates and returns the next `RuleNode`. Updates `NestedRulenodeIterator`'s internal state to prepare it for a subsequent call.
"""
function get_next_rulenode!(
    nested_rulenode_iterator::NestedRulenodeIterator
)::Union{RuleNode, Nothing}
    nested_rulenode_iteration_result = _iterate(nested_rulenode_iterator)
    if nested_rulenode_iteration_result === nothing 
        return nothing
    end

    (rulenode_children, nested_rulenode_iterator.state) = nested_rulenode_iteration_result
    return RuleNode(nested_rulenode_iterator.rule, collect(rulenode_children))
end

"""
    function _iterate(nested_rulenode_iterator::NestedRulenodeIterator)::Union{RuleNode, Nothing}

Helper function for returning the next tuple returned by `iterate`. Returns `nothing` when no other elements can be iterated.
"""
function _iterate(
    nested_rulenode_iterator::NestedRulenodeIterator
)
    if nested_rulenode_iterator.state === nothing
        return iterate(nested_rulenode_iterator.collection)
    end
    return iterate(nested_rulenode_iterator.collection, nested_rulenode_iterator.state) 
end
