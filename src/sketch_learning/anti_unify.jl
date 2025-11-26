"""
    anti_unify(t1::RuleNode, t2::RuleNode, grammar::ContextSensitiveGrammar)

Compute the least general generalization (LGG), also known as the
anti-unification of two ASTs represented as `RuleNode`s.
This function tries to find a common syntactic structure shared by both trees.
"""

function anti_unify(t1::AbstractRuleNode, t2::AbstractRuleNode, grammar::ContextSensitiveGrammar)

    # --- Case A: HOLE vs HOLE ---
    if t1 isa UniformHole && t2 isa UniformHole
        # intersection domain keeps more specific domain
        merged_domain = t1.domain .& t2.domain
        return UniformHole(merged_domain)
    end

    # --- Case: one of the trees is UniformHole ---
    if t1 isa UniformHole
        rule2 = get_rule(t2)
        t1.domain[rule2] || return nothing
        return t1
    elseif t2 isa UniformHole
        rule1 = get_rule(t1)
        t2.domain[rule1] || return nothing
        return t2 
    end


    rule1 = get_rule(t1)
    rule2 = get_rule(t2)

    if rule1 == rule2
        c1 = get_children(t1)
        c2 = get_children(t2)

        length(c1) == length(c2) || return nothing

        unified_children = AbstractRuleNode[]

        for i in 1:length(c1)
            child_u = anti_unify(c1[i], c2[i], grammar)
            child_u == nothing && return nothing
            push!(unified_children, child_u)
        end
   
        return RuleNode(rule1, unified_children)
        
    else 

        type1 = return_type(grammar, rule1)
        type2 = return_type(grammar, rule2) 
         

        if type1 == type2
            domain = get_domain(grammar, type1)
            return UniformHole(domain)
        else
            return nothing
        end
    end  
end

"""
    all_pairwise_anti_unifications(tree_1, tree_2, grammar)

Compute anti-unifications between ALL subtree pairs of tree_1 and tree_2.
Return a vector of successful unified patterns.
"""
function all_pairwise_anti_unification(tree_1::AbstractRuleNode,
                                       tree_2::AbstractRuleNode,
                                       grammar::ContextSensitiveGrammar;
                                       min_nonholes=0,
                                       max_holes=3)

    subtrees_1 = collect_subtrees(tree_1)
    subtrees_2 = collect_subtrees(tree_2)

    patterns = AbstractRuleNode[]

    for subtree_1 in subtrees_1
        for subtree_2 in subtrees_2
            
            u = anti_unify(subtree_1, subtree_2, grammar)
            if u !== nothing && passes_hole_thresholds(u; min_nonholes=min_nonholes, max_holes=max_holes) && length(get_children(u))>0
                push!(patterns, u)
            end
        end
    end

    return patterns

end

"""
    all_pairwise_anti_unifications(tree_1, tree_2, grammar)

Compute anti-unifications between patterns(trees) and a tree.
Return a vector of common patterns.
"""
function anti_unify_patterns_and_tree(
    pattterns::Vector{AbstractRuleNode},
    tree::AbstractRuleNode,
    grammar::ContextSensitiveGrammar;
    min_nonholes=0,
    max_holes=3
)
    subtrees = collect_subtrees(tree)
    final_patterns = AbstractRuleNode[]

    for pattern in pattterns
        for subtree in subtrees
            if length(get_children(subtree)) == 0
                continue
            end

            u = anti_unify(subtree, pattern, grammar)
            if u !== nothing && passes_hole_thresholds(u; min_nonholes=min_nonholes, max_holes=max_holes) && length(get_children(u)) > 0
                push!(final_patterns, u)
            end
        end
    end

    return final_patterns
end


function multi_MST_unify(
    trees::Vector{AbstractRuleNode},
    grammar::ContextSensitiveGrammar;
    min_nonholes=0,
    max_holes=3
)
    n = length(trees)
    n < 2 && return AbstractRuleNode[]

    patterns = all_pairwise_anti_unification(
        trees[1], trees[2], grammar;
        min_nonholes=min_nonholes,
        max_holes=max_holes
    )


    for i in 3:length(trees)
        patterns = anti_unify_patterns_and_tree(
            patterns, trees[i], grammar;
            min_nonholes=min_nonholes,
            max_holes=max_holes
        )
        isempty(patterns) && break
    end

    return patterns
end
