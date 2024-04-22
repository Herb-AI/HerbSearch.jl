"""
    crossover_swap_children_2(parent1::RuleNode, parent2::RuleNode, grammar::AbstractGrammar)

Performs a random crossover of two parents of type [`RuleNode`](@ref). The subprograms are swapped and both altered parent programs are returned.
"""
function crossover_swap_children_2(parent1::RuleNode, parent2::RuleNode, grammar::AbstractGrammar)
    copyparent1 = deepcopy(parent1)
    copyparent2 = deepcopy(parent2)
    
    node_location1::NodeLoc = sample(NodeLoc, copyparent1)
    subprogram1 = get(copyparent1, node_location1)
    node_type = return_type(grammar, subprogram1)
    # make sure that the second subtree has a matching node type 

    # TODO: Take into account the case when the sample fails because there is no matching node.
    # This does not happend too often but sometimes it happens.
    # TODO: Propagate grammar constraints here.

    node_location2::NodeLoc = sample(NodeLoc, copyparent2, node_type, grammar)
    subprogram2 = get(copyparent2, node_location2)

    
    if node_location1.i != 0
        insert!(copyparent1, node_location1, subprogram2, grammar)
    else
        copyparent1 = subprogram2
    end
    if node_location2.i != 0
        insert!(copyparent2, node_location2, subprogram1, grammar)
    else 
        copyparent2 = subprogram1
    end
    return (copyparent1,copyparent2)
end

"""
    crossover_swap_children_1(parent1::RuleNode, parent2::RuleNode, grammar::AbstractGrammar)

Performs a random crossover of two parents of type [`RuleNode`](@ref). The subprograms are swapped and only one altered parent program is returned.
"""
function crossover_swap_children_1(parent1::RuleNode, parent2::RuleNode, grammar::AbstractGrammar)
    copyparent1 = deepcopy(parent1)
    copyparent2 = deepcopy(parent2)
    
    node_location1::NodeLoc = sample(NodeLoc, copyparent1)
    subprogram1 = get(copyparent1, node_location1)
    node_type = return_type(grammar, subprogram1)
    
    # make sure that the second subtree has a matching node type 
    node_location2::NodeLoc = sample(NodeLoc, copyparent2, node_type, grammar)
    subprogram2 = get(copyparent2, node_location2)

    if rand() <= 0.5
        if node_location1.i != 0
            insert!(copyparent1, node_location1, subprogram2, grammar)
        else
            copyparent1 = subprogram2
        end
        return copyparent1
    end
    if node_location2.i != 0
        insert!(copyparent2, node_location2, subprogram1, grammar)
    else 
        copyparent2 = subprogram1
    end

    return copyparent2
end