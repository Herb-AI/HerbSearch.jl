"""
    mutate_random!(program::RuleNode, grammar::Grammar, max_depth::Int64 = 2)

Mutates the given program by inserting a randomly generated sub-program at a random location.
"""
function mutate_random!(program::RuleNode, grammar::Grammar, max_depth::Int64 = 2)
    node_location::NodeLoc = sample(NodeLoc, program)
    random_program = rand(RuleNode, grammar,  max_depth)
    insert!(program, node_location, random_program)
end

