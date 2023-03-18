function constructNeighbourhood(current_program::RuleNode, grammar::Grammar)
    # get a random position in the tree (parent,child index)
    node_location::NodeLoc = sample(NodeLoc, current_program)
    return node_location, nothing
end

function constructNeighbourhoodRuleSubset(current_program::RuleNode, grammar::Grammar)
    # get a random position in the tree (parent,child index)
    node_location::NodeLoc = sample(NodeLoc, current_program)
    rule_subset_size = rand((0, length(grammar.rules)))
    rule_subset = sample(collect(grammar.rules), rule_subset_size, replace=false)
    dict = Dict("rule_subset" => rule_subset)
    return node_location, dict
end