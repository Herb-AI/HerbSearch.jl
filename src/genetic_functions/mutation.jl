"""
    mutate_random!(program::RuleNode, grammar::Grammar)

Mutates the given program by inserting a randomly generated sub-program at a random location.
"""
function mutate_random!(program::RuleNode, grammar::Grammar)
    node_location::NodeLoc = sample(NodeLoc, program)
    subprogram = get(program, node_location)
    symbol = return_type(grammar, subprogram)

    random_program = rand(RuleNode, grammar, symbol)
    insert!(program, node_location, random_program)
end

