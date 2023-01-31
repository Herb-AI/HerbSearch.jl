abstract type ExpressionIterator end


"""
		ContextFreeEnumerator(grammar::Grammar, max_depth::Int, sym::Symbol)
An iterator over all possible expressions of a grammar up to max_depth with start symbol sym.
Types of search depends on the order of production rules in the given grammar: BFS - terminals come first; DFS: nonterminals come first
"""
mutable struct ContextFreeEnumerator <: ExpressionIterator
    grammar::ContextFreeGrammar
    max_depth::Int
    sym::Symbol
end

Base.IteratorSize(::ExpressionIterator) = Base.SizeUnknown()

Base.eltype(::ExpressionIterator) = RuleNode

function Base.iterate(iter::ExpressionIterator)
    grammar, sym, max_depth = iter.grammar, iter.sym, iter.max_depth
    node = RuleNode(grammar[sym][1])
    if isterminal(grammar, node)
        return (deepcopy(node), node)
    else
        node, worked =  _next_state!(node, grammar, max_depth)
        while !worked
            # increment root's rule
            rules = grammar[sym]
            i = something(findfirst(isequal(node.ind), rules), 0)
            if i < length(rules)
                node, worked = RuleNode(rules[i+1]), true
                if !isterminal(grammar, node)
                    node, worked = _next_state!(node, grammar, max_depth)
                end
            else
                break
            end
        end
        return worked ? (deepcopy(node), node) : nothing
    end
end

function Base.iterate(iter::ExpressionIterator, state::RuleNode)
    grammar, max_depth = iter.grammar, iter.max_depth
    node, worked = _next_state!(state, grammar, max_depth)

    while !worked
        # increment root's rule
        rules = grammar[iter.sym]
        i = something(findfirst(isequal(node.ind), rules), 0)
        if i < length(rules)
            node, worked = RuleNode(rules[i+1]), true
            if !isterminal(grammar, node)
                node, worked = _next_state!(node, grammar, max_depth)
            end
        else
            break
        end
    end
    return worked ? (deepcopy(node), node) : nothing
end

"""
    count_expressions(grammar::Grammar, max_depth::Int, sym::Symbol)
Count the number of possible expressions of a grammar up to max_depth with start symbol sym.
"""
function count_expressions(grammar::Grammar, max_depth::Int, sym::Symbol)
    retval = 0
    for root_rule in grammar[sym]
        node = RuleNode(root_rule)
        if isterminal(grammar, node)
            retval += 1
        else
            node, worked = _next_state!(node, grammar, max_depth)
            while worked
                retval += 1
                node, worked = _next_state!(node, grammar, max_depth)
            end
        end
    end
    return retval
end

function _next_state!(node::RuleNode, grammar::Grammar, max_depth::Int)

	if max_depth < 1
	    return (node, false) # did not work
	elseif isterminal(grammar, node)
	    # do nothing
	    if iseval(grammar, node.ind) && (node._val === nothing)  # evaluate the rule
		node._val = eval(grammar.rules[node.ind].args[2])
	    end
	    return (node, false) # cannot change leaves
	else # !isterminal
	    # if node is not terminal and doesn't have children, expand every child
	    if isempty(node.children)  
		if max_depth ≤ 1
		    return (node,false) # cannot expand
		end
    
		# build out the node
		for c in child_types(grammar, node)
    
		    worked = false
		    i = 0
		    child = RuleNode(0)
		    child_rules = grammar[c]
		    while !worked && i < length(child_rules)
			i += 1
			child = RuleNode(child_rules[i])
    
			if iseval(grammar, child.ind) # if rule needs to be evaluated (_())
			    child._val = eval(grammar.rules[child.ind].args[2])
			end
			worked = true
			if !isterminal(grammar, child)
			    child, worked = _next_state!(child, grammar, max_depth-1)
			end
		    end
		    if !worked
			return (node, false) # did not work
		    end
		    push!(node.children, child)
		end
    
		return (node, true)
	    else # not empty
		# make one change, starting with rightmost child
		worked = false
		child_index = length(node.children) + 1
		while !worked && child_index > 1
		    child_index -= 1
		    child = node.children[child_index]
    
		    # this modifies the node if succesfull
		    child, child_worked = _next_state!(child, grammar, max_depth-1)
		    while !child_worked
			child_type = return_type(grammar, child)
			child_rules = grammar[child_type]
			i = something(findfirst(isequal(child.ind), child_rules), 0)
			if i < length(child_rules)
			    child_worked = true
			    child = RuleNode(child_rules[i+1])
    
			    # node needs to be evaluated
			    if iseval(grammar, child.ind)
				child._val = eval(grammar.rules[child.ind].args[2])
			    end
    
			    if !isterminal(grammar, child)
				child, child_worked = _next_state!(child, grammar, max_depth-1)
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
			    child_rules = grammar[c]
			    while !worked && i < length(child_rules)
				i += 1
				child = RuleNode(child_rules[i])
    
				if iseval(grammar, child.ind)
				    child._val = eval(grammar.rules[child.ind].args[2])
				end
    
				worked = true
				if !isterminal(grammar, child)
				    child, worked = _next_state!(child, grammar, max_depth-1)
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

"""
    count_expressions(iter::ExpressionIterator)
Count the number of possible expressions in the expression iterator.
"""
count_expressions(iter::ExpressionIterator) = count_expressions(iter.grammar, iter.max_depth, iter.sym)