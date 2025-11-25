"""
    anti_unify(t1::RuleNode, t2::RuleNode, grammar::ContextSensitiveGrammar)

Compute the least general generalization (LGG), also known as the
anti-unification of two ASTs represented as `RuleNode`s.
This function tries to find a common syntactic structure shared by both trees.
"""

function anti_unify(t1::RuleNode, t2::RuleNode, grammar::ContextSensitiveGrammar)

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
