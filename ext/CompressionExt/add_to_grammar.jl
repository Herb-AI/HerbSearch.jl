using DocStringExtensions

function _needs_splitting(hole::UniformHole, g)
    !isempty(hole.children) && return true
    hole_type = g.types[findfirst(==(1), hole.domain)]
    return g.domains[hole_type] != hole.domain
end

function _split_hole(rule::RuleNode, g)
    isempty(rule.children) && return [rule]
    splits = []
    children_res = [_split_hole(ch, g) for ch in rule.children]
    for children in Iterators.product(children_res...)
        new_rule = RuleNode(get_rule(rule), collect(children))
        push!(splits, new_rule)
    end
    return splits
end

function _split_hole(hole::UniformHole, g)
    splits = []
    isfilled(hole) && return [hole]
    _needs_splitting(hole, g) || return [hole]
    children_res = [_split_hole(ch, g) for ch in hole.children]
    for (i, d) in enumerate(hole.domain)
        d || continue
        for children in Iterators.product(children_res...)
            new_rule = RuleNode(i, collect(children))
            push!(splits, new_rule)
        end
    end
    return splits
end

function split_hole(hole::Union{UniformHole, RuleNode}, g)
    splits = _split_hole(hole, g)
    return rulenode2expr.(splits, (g,))
end

"""
    $(TYPEDSIGNATURES)

Given a rule that may contain holes, returns new rules structured like.
Main_Rule = New_type
New_type = ...
New_type = ...

The *Main_Rule* is the 1st element of the returned rules.
"""
function create_new_exprs(rule::Union{UniformHole, RuleNode}, g, iter_id::Int, rule_num::Int)
    splits = split_hole(rule, g)
    rule_type = return_type(g, rule)
    if length(splits) == 1 
        return [:($rule_type = $(only(splits)))]
    end
    
    new_type = Symbol("_Rule_$(iter_id)_$(rule_num)")
    head_rule = :($rule_type = $new_type) 
    new_expressions = [head_rule]
    for expr in splits
        push!(new_expressions, :($new_type = $expr))
    end
    return new_expressions
end