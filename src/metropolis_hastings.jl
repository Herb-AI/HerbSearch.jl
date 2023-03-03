# using Random

# include("stochastic_search_iterator.jl")


# """
# MetropolisHastingsEnumerator(grammar::Grammar, max_depth::Int, sym::Symbol)
# An iterator over all possible expressions of a grammar up to max_depth with start symbol sym.
# """
# mutable struct MetropolisHastingsEnumerator <: ExpressionIterator
#     grammar::ContextFreeGrammar
#     max_depth::Int
#     sym::Symbol
#     examples::AbstractVector{Example}
# end

# Base.IteratorSize(::ExpressionIterator) = Base.SizeUnknown()
# Base.eltype(::ExpressionIterator) = RuleNode

# function Base.iterate(iter::ExpressionIterator)
#     grammar, max_depth = iter.grammar, iter.max_depth
#     node = rand(RuleNode, grammar, :Real, max_depth)
#     return (deepcopy(node), node)
# end



# function Base.iterate(iter::ExpressionIterator, curr_expression::RuleNode)
#     grammar,sym, max_depth = iter.grammar,iter.sym, iter.max_depth
#     # get a random position in the tree (parent,child index)
#     node_location::NodeLoc = sample(NodeLoc, curr_expression, sym, grammar, max_depth)

#     # generate completely random expression 
#     new_random = rand(RuleNode,grammar,sym,max_depth)

#     next_expression = curr_expression
#     # replace node at node_location with new_random 
#     if node_location.i == 0
#         next_expression = new_random
#     else 
#         # child_to_replace = node_location.parent.children[node_location.i]
#         node_location.parent.children[node_location.i] = new_random
#         # println("Selected node ",Grammars.rulenode2expr(child_to_replace,grammar))
#     end     

#     symboltable :: SymbolTable = Grammars.SymbolTable(grammar)

#     expr_after = Grammars.rulenode2expr(next_expression, grammar)
#     expr_now = Grammars.rulenode2expr(curr_expression, grammar)

#     above = Evaluation.ratio_correct_examples(symboltable, expr_after, iter.examples)
#     below = Evaluation.ratio_correct_examples(symboltable, expr_now, iter.examples)
#     ratio = above/below 
    
#     if below == 0
#         ratio = 1
#     end 

#     # println("ratio is ",ratio," above ", above, " below ",below)
#     if ratio >= 1
#         # println("Accepted!");
#         return (deepcopy(next_expression),next_expression)
#     end 

#     random_number = rand()
#     if ratio >= random_number
#         # println("Accepted!");
#         return (deepcopy(next_expression),next_expression)
#     end
    
#     # return current expression
#     # println("Rejected");
#     return (deepcopy(curr_expression),curr_expression)

# end



# function constructNeighbourhood(current_program::RuleNode, grammar::Grammar)
#     # get a random position in the tree (parent,child index)
#     node_location::NodeLoc = sample(current_program, grammar)
#     return node_location, nothing
# end

# function temperature(previous_temperature)
#     return previous_temperature
# end

# function propose(current_program, neighbourhood_node_loc, neighbourhood_symbol, grammar, max_depth, dict)
#     # generate completely random expression 
#     new_random = rand(RuleNode,grammar,neighbourhood_symbol,max_depth)

#     next_program = current_program
#     # replace node at node_location with new_random 
#     if neighbourhood_node_loc.i == 0
#         next_program = new_random
#     else 
#         # child_to_replace = node_location.parent.children[node_location.i]
#         neighbourhood_node_loc.parent.children[neighbourhood_node_loc.i] = new_random
#         # println("Selected node ",Grammars.rulenode2expr(child_to_replace,grammar))
#     end
    
#     # TODO handle max_depth correctly (max depth of the problem)

#     return [next_program]
# end

# function accept(current_program_cost, program_cost)
#     ratio = program_cost/current_program_cost 
    
#     if below == 0
#         ratio = 1
#     end 

#     # println("ratio is ",ratio," above ", above, " below ",below)
#     if ratio >= 1
#         # println("Accepted!");
#         return true
#     end 

#     random_number = rand()
#     if ratio >= random_number
#         # println("Accepted!");
#         return true
#     end

#     return false
# end

# function cost_function(results::AbstractVector{Tuple{Any, Any}})
#     cost = 0
#     for (expected, actual) in results
#         cost += (expected - actual)^2
#     end
#     return cost / length(results)
# end
