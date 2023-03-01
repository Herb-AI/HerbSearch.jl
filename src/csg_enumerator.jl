"""
Reduces the set of possible children of a node using the grammar's constraints
"""
function propagate_constraints(
        grammar::ContextSensitiveGrammar, 
        context::GrammarContext, 
        child_rules::Vector{Int}
    )
    domain = child_rules

    for propagator ∈ grammar.constraints
        domain = propagate(propagator, context, domain)
    end

    return domain
end

mutable struct ContextSensitiveEnumerator <: ExpressionIterator
    grammar::ContextSensitiveGrammar
    max_depth::Int
    sym::Symbol
end


function Base.iterate(iter::ContextSensitiveEnumerator)
    init_node = RuleNode(0)  # needed for propagating constraints on the root node 
    init_context = GrammarContext(init_node)

    grammar, sym, max_depth = iter.grammar, iter.sym, iter.max_depth

    # propagate constraints on the root node 
    sym_rules = [x for x ∈ grammar[sym]]
    sym_rules = propagate_constraints(grammar, init_context, sym_rules)
    #node = RuleNode(grammar[sym][1])
    node = RuleNode(sym_rules[1])

    if isterminal(grammar, node)
        return (deepcopy(node), node)
    else
        context = GrammarContext(node, grammar)
        node, worked = _next_state!(node, grammar, max_depth, context)
        while !worked
            # increment root's rule
            rules = [x for x in grammar[sym]]
            rules = propagate_constraints(grammar, init_context, rules) # propagate constraints on the root node

            i = something(findfirst(isequal(node.ind), rules), 0)
            if i < length(rules)
                node, worked = RuleNode(rules[i+1]), true
                if !isterminal(grammar, node)
                    node, worked = _next_state!(node, grammar, max_depth, context)
                end
            else
                break
            end
        end
        return worked ? (deepcopy(node), node) : nothing
    end
end


function Base.iterate(iter::ContextSensitiveEnumerator, state::RuleNode)
    grammar, max_depth = iter.grammar, iter.max_depth
    context = GrammarContext(state, grammar)
    node, worked = _next_state!(state, grammar, max_depth, context)
    
    while !worked
        # increment root's rule
        init_node = RuleNode(0)  # needed for propagating constraints on the root node 
        init_context = GrammarContext(init_node, grammar)

        rules = [x for x ∈ grammar[iter.sym]]
        rules = propagate_constraints(grammar, init_context, rules)

        i = something(findfirst(isequal(node.ind), rules), 0)
        if i < length(rules)
            node, worked = RuleNode(rules[i+1]), true
            if !isterminal(grammar, node)
                context = GrammarContext(node, grammar)
                node, worked = _next_state!(node, grammar, max_depth, context)
            end
        else
            break
        end
    end
    return worked ? (deepcopy(node), node) : nothing
end

"""
reimplementation of cfg _next_state!
Change: child expressions are filtered so that the constraints are not violated
"""
function _next_state!(node::RuleNode, grammar::ContextSensitiveGrammar, max_depth::Int, context::GrammarContext)

    if max_depth < 1
        return (node, false) # did not work
    elseif isterminal(grammar, node)
        # do nothing
        if iseval(grammar, node.ind) && (node._val ≡ nothing)  # evaluate the rule
            node._val = eval(grammar.rules[node.ind].args[2])
        end
        return (node, false) # cannot change leaves
    else # !isterminal
        # if node is not terminal and doesn't have children, expand every child
        if isempty(node.children)  
            if max_depth ≤ 1
                return (node,false) # cannot expand
            end

            child_index = 1  # keep track of which child we are processing now (needed for context)
        
            # build out the node
            for c in child_types(grammar, node)
                worked = false
                i = 0
                child = RuleNode(0)

                new_context = GrammarContext(context.originalExpr, deepcopy(context.nodeLocation), grammar)
                push!(new_context.nodeLocation, child_index)

                child_rules = [x for x in grammar[c]]  # select all applicable rules
                child_rules = propagate_constraints(grammar, new_context, child_rules)  # filter out those that violate constraints

                while !worked && i < length(child_rules)
                    i += 1
                    child = RuleNode(child_rules[i])
            
                    if iseval(grammar, child.ind) # if rule needs to be evaluated (_())
                        child._val = eval(grammar.rules[child.ind].args[2])
                    end

                    worked = true
                    if !isterminal(grammar, child)
                        child, worked = _next_state!(child, grammar, max_depth-1, new_context)
                    end
                end
                if !worked
                    return (node, false) # did not work
                end
                push!(node.children, child)

                child_index += 1
            end
            return (node, true)
        else # not empty
            # make one change, starting with rightmost child
            worked = false
            child_index = length(node.children) + 1
            while !worked && child_index > 1
                child_index -= 1
                child = node.children[child_index]
        
                new_context = GrammarContext(context.originalExpr, deepcopy(context.nodeLocation), grammar)
                push!(new_context.nodeLocation, child_index)

                child, child_worked = _next_state!(child, grammar, max_depth-1, new_context)
                while !child_worked
                    child_type = return_type(grammar, child)

                    child_rules = [x for x in grammar[child_type]]  # get all applicable rules
                    child_rules = propagate_constraints(grammar, new_context, child_rules)  # filter ones that violate constraints


                    i = something(findfirst(isequal(child.ind), child_rules), 0)
                    if i < length(child_rules)
                        child_worked = true
                        child = RuleNode(child_rules[i+1])
            
                        # node needs to be evaluated
                        if iseval(grammar, child.ind)
                            child._val = eval(grammar.rules[child.ind].args[2])
                        end
            
                        if !isterminal(grammar, child)
                            child, child_worked = _next_state!(child, grammar, max_depth-1, new_context)
                        end
                        node.children[child_index] = child
                    else
                        break
                    end
                end
        
                if child_worked
                    worked = true
        
                    # reset remaining children
                    for child_index2 in child_index+1 : length(node.children)
                        c = child_types(grammar, node)[child_index2]
                        worked = false
                        i = 0
                        child = RuleNode(0)

                        new_context = GrammarContext(context.originalExpr, deepcopy(context.nodeLocation), grammar)
                        push!(new_context.nodeLocation, child_index2)

                        child_rules = [x for x in grammar[c]]  # take all applicable rules
                        child_rules = propagate_constraints(grammar, new_context, child_rules)  # remove ones that violate constraints


                        while !worked && i < length(child_rules)
                            i += 1
                            child = RuleNode(child_rules[i])
                
                            if iseval(grammar, child.ind)
                                child._val = eval(grammar.rules[child.ind].args[2])
                            end
                
                            worked = true
                            if !isterminal(grammar, child)
                                child, worked = _next_state!(child, grammar, max_depth-1, new_context)
                            end
                        end
                        if !worked
                            break
                        end
                        node.children[child_index2] = child
                    end
                end
            end
        
            return (node, worked)
        end
    end
end