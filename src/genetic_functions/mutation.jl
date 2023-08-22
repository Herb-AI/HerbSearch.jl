function random_mutate!(program::RuleNode, grammar::Grammar, max_depth::Int64 = 2)
    node_location::NodeLoc = sample(NodeLoc, program)
    random_program = rand(RuleNode, grammar,  max_depth)
    insert!(program, node_location, random_program)
end

