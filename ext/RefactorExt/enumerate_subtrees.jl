using DataStructures

"""
    enumerate_subtrees(tree::RuleNode, grammar::AbstractGrammar)

Enumerates all subtrees of a given tree ([`RuleNode`](@ref)). Returns a vector listing all subtrees of the tree.

# Arguments
- `tree::RuleNode`: the tree to enumerate the subtrees of
- `grammar::AbstractGrammar`: the grammar to use
"""
function enumerate_subtrees(tree::RuleNode, grammar::AbstractGrammar)::Vector{RuleNode}
    (subtrees, other_subtrees) = _enumerate_subtrees_rec(tree, grammar)
    return vcat(subtrees, other_subtrees)
end


"""
    _enumerate_subtrees_rec(tree::RuleNode, g::AbstractGrammar)

Enumerates all subtrees of a given tree ([`RuleNode`](@ref)).

# Arguments
- `tree::RuleNode`: the tree to enumerate the subtrees of
- `g::AbstractGrammar`: the grammar to use

# Result
- `subtrees::(Vector{RuleNode},Vector{RuleNode})`: a tuple of a list of all subtrees of the tree and a list of all other subtrees
"""
function _enumerate_subtrees_rec(tree::RuleNode, grammar::AbstractGrammar)
    if length(tree.children) == 0
        return ([tree], [])
    end   
    child_subtrees = []
    subtrees_tree_root = []# subtrees with parent node
    other_subtrees = [] # subtrees without parent node

    for child in tree.children
        (subtrees_child, other_subtrees_child) = _enumerate_subtrees_rec(child, grammar)
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
                    hole = Hole(get_domain(grammar, grammar.bytype[child_types(grammar, candidate)[i]]))
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

# Returns
- `combinations::Vector{Vector{Bool}}`: a list of all combinations
"""
combinations(n::Int) = Iterators.product([[true,false] for _ in 1:n]...)

"""
    selection_criteria(tree::RuleNode, subtree::AbstractRuleNode)

Determines whether a subtree should be selected.

# Arguments
- `tree::RuleNode`: the tree
- `subtree::AbstractRuleNode`: the subtree

# Returns
- `Bool`: true if the subtree should be selected, false otherwise
"""
function selection_criteria(tree::RuleNode, subtree::AbstractRuleNode)
    size = length(subtree)
    return size > 1 #&& size < length(tree)
end

