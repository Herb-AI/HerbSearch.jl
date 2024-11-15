
"""
    conquer_combine(problems_to_solutions:: Dict{Problem, Vector{RuleNode}})

Takes in the problems with the found solutions and combines them into a global solution program 
by combining them into a decision tree.
"""
function conquer_combine(problems_to_solutions:: Dict{Problem, Vector{RuleNode}}, grammar, num_predicates, sym_bool, sym_start)
    # TODO
    # labels: problem-solution-map
    # predicates: new BFSIterator over grammar, start symbol Bool
    # Use predicates and sub-problems to get features.
    # Take labls and features to make DecisionTree
    # See decision tree example: https://github.com/Herb-AI/HerbSearch.jl/blob/subset-search/src/subset_iterator.jl
end


