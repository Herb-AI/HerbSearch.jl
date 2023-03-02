using Random


"""
MetropolisHastingsEnumerator(grammar::Grammar, max_depth::Int, sym::Symbol)
An iterator over all possible expressions of a grammar up to max_depth with start symbol sym.
"""
mutable struct MetropolisHastingsEnumerator <: ExpressionIterator
    grammar::ContextFreeGrammar
    max_depth::Int
    sym::Symbol
    examples::AbstractVector{Example}
end

Base.IteratorSize(::ExpressionIterator) = Base.SizeUnknown()
Base.eltype(::ExpressionIterator) = RuleNode

function Base.iterate(iter::ExpressionIterator)
    grammar, sym, max_depth = iter.grammar, iter.sym, iter.max_depth
    node = rand(RuleNode,grammar,sym,max_depth)
    return (deepcopy(node), node)
end



function Base.iterate(iter::ExpressionIterator, curr_expression::RuleNode)
    grammar,sym, max_depth = iter.grammar,iter.sym, iter.max_depth
    # get a random position in the tree (parent,child index)
    node_location::NodeLoc = sample(NodeLoc, curr_expression, sym, grammar, max_depth)

    # generate completely random expression 
    new_random = rand(RuleNode,grammar,sym,max_depth)

    next_expression = curr_expression
    # replace node at node_location with new_random 
    if node_location.i == 0
        next_expression = new_random
    else 
        # child_to_replace = node_location.parent.children[node_location.i]
        node_location.parent.children[node_location.i] = new_random
        # println("Selected node ",Grammars.rulenode2expr(child_to_replace,grammar))
    end     

    symboltable :: SymbolTable = Grammars.SymbolTable(grammar)

    expr_after = Grammars.rulenode2expr(next_expression, grammar)
    expr_now = Grammars.rulenode2expr(curr_expression, grammar)

    above = Evaluation.ratio_correct_examples(symboltable, expr_after, iter.examples)
    below = Evaluation.ratio_correct_examples(symboltable, expr_now, iter.examples)
    ratio = above/below 
    
    if below == 0
        ratio = 1
    end 

    # println("ratio is ",ratio," above ", above, " below ",below)
    if ratio >= 1
        # println("Accepted!");
        return (deepcopy(next_expression),next_expression)
    end 

    random_number = rand()
    if ratio >= random_number
        # println("Accepted!");
        return (deepcopy(next_expression),next_expression)
    end
    
    # return current expression
    # println("Rejected");
    return (deepcopy(curr_expression),curr_expression)

end