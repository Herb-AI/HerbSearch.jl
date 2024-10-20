mutable struct NestedRulenodeIterator
    collection::Any,
    state::Any,

    next_rulenode::RuleNode
end

function NestedRulenodeIterator(collection::Any)::NestedRulenodeIterator
    (next_rulenode, state) = iterate(collection)
    return NestedRulenodeIterator(collection, state, next_rulenode)
end

function get_next_rulenode(
    nested_rulenode_iterator::NestedRulenodeIterator
)::RuleNode
    collection::Any = nested_rulenode_iterator.collection
    state::Any = nested_rulenode_iterator.state

    current_rulenode::RuleNode = next_rulenode
    (nested_rulenode_iterator.next_rulenode, nested_rulenode_iterator.state) = iterate(collection, state)
    return current_rulenode
end