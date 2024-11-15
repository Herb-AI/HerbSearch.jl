using DataStructures

"""
    enumerate_subtrees(tree::RuleNode, g::AbstractGrammar)

Enumerates all subtrees of a given tree.
# Arguments
- `tree::RuleNode`: the tree to enumerate the subtrees of
- `g::AbstractGrammar`: the grammar to use
# Result
- `subtrees::Vector{RuleNode}`: a list of all subtrees of the tree
"""
function enumerate_subtrees(tree::RuleNode, g::AbstractGrammar)
    (subtrees, other_subtrees) = enumerate_subtrees_rec(tree, g)
    return vcat(subtrees, other_subtrees)
end


"""
    enumerate_subtrees_rec(tree::RuleNode, g::AbstractGrammar)

Enumerates all subtrees of a given tree.
# Arguments
- `tree::RuleNode`: the tree to enumerate the subtrees of
- `g::AbstractGrammar`: the grammar to use
# Result
- `subtrees::(Vector{RuleNode},Vector{RuleNode})`: a tuple of a list of all subtrees of the tree and a list of all other subtrees
"""
function enumerate_subtrees_rec(tree::RuleNode, g::AbstractGrammar)
    if length(tree.children) == 0
        return ([tree], [])
    end   
    child_subtrees = []
    subtrees_tree_root = []# subtrees with papa node
    other_subtrees = [] # subtrees without papa node

    for child in tree.children
        (subtrees_child, other_subtrees_child) = enumerate_subtrees_rec(child, g)
        push!(child_subtrees, subtrees_child)
        other_subtrees = vcat(other_subtrees, subtrees_child, other_subtrees_child)
    end

    # for every combination
    for perm in combinations(length(tree.children))
        
        subtree_candidates = cons(deepcopy(tree), nil()) # copy the tree
        # for every child
        for (i, include) in pairs(perm)
            for candidate in subtree_candidates
                if include
                    for (j, child_subtree) in pairs(child_subtrees[i])
                        subtree = j == 1 ? candidate : deepcopy(candidate)
                        subtree.children[i] = child_subtree
                        if j != 1
                            subtree_candidates = cons(subtree, subtree_candidates)
                        end
                    end
                else
                    hole = Hole(get_domain(g, g.bytype[child_types(g, candidate)[i]]))
                    candidate.children[i] = hole
                end
            end
        end	
        subtrees_tree_root = vcat([candidate for candidate in subtree_candidates], subtrees_tree_root)
    end

    return (subtrees_tree_root, other_subtrees)
end


"""
    combinations(n::Int)

Generates all combinations of n elements.
# Arguments
- `n::Int`: the number of elements
# Result
- `combinations::Vector{Vector{Bool}}`: a list of all combinations
"""
function combinations(n::Int)
    if n == 0
        return [[]]
    end
    smaller_combinations = combinations(n - 1)
    return vcat([vcat(true, perm) for perm in smaller_combinations], 
        [vcat(false, perm) for perm in smaller_combinations])
end

"""
    selection_criteria(tree::RuleNode, subtree::AbstractRuleNode)

Determines whether a subtree should be selected.
# Arguments
- `tree::RuleNode`: the tree
- `subtree::AbstractRuleNode`: the subtree
# Result
- `Bool`: true if the subtree should be selected, false otherwise
"""
function selection_criteria(tree::RuleNode, subtree::AbstractRuleNode)
    size = length(subtree)
    return size > 1 && size < length(tree)
end