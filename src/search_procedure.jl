"""
Searches the grammar up to the provided depth for a program that satisfies problem
# """
# function enumerative_search(g::Grammars.ContextFreeGrammar, problem::Data.Problem, depth::Int, enumerator=ContextFreeEnumerator) :: Expr
#     symboltable :: SymbolTable = Grammars.SymbolTable(g)

#     hypotheses = enumerator(g, depth, :Real)

#     for h :: RuleNode ∈ hypotheses
#         # Create expression from rulenode representation of AST
#         expr = Grammars.rulenode2expr(h, g)
#         # Evaluate examples the examples.
#         #  `evaluate examples` returns as soon as it has found the first example that doesn't work.
#         if Evaluation.evaluate_examples(symboltable, expr, problem.examples)
#             return expr
#         end
#     end
# end

function constructNeighbourhood(current_program::RuleNode, grammar::Grammar)
    # get a random position in the tree (parent,child index)
    node_location::NodeLoc = sample(current_program, grammar)
    return node_location, nothing
end

function temperature(previous_temperature)
    return previous_temperature
end

function propose(current_program, neighbourhood_node_loc, neighbourhood_symbol, grammar, max_depth, dict)
    # generate completely random expression 
    new_random = rand(RuleNode,grammar,neighbourhood_symbol,max_depth)

    next_program = current_program
    # replace node at node_location with new_random 
    if neighbourhood_node_loc.i == 0
        next_program = new_random
    else 
        # child_to_replace = node_location.parent.children[node_location.i]
        neighbourhood_node_loc.parent.children[neighbourhood_node_loc.i] = new_random
        # println("Selected node ",Grammars.rulenode2expr(child_to_replace,grammar))
    end
    
    # TODO handle max_depth correctly (max depth of the problem)

    return [next_program]
end

function accept(current_program_cost, program_cost)
    ratio = program_cost/current_program_cost 
    
    if below == 0
        ratio = 1
    end 

    # println("ratio is ",ratio," above ", above, " below ",below)
    if ratio >= 1
        # println("Accepted!");
        return true
    end 

    random_number = rand()
    if ratio >= random_number
        # println("Accepted!");
        return true
    end

    return false
end

function cost_function(results::AbstractVector{Tuple{Any, Any}})
    cost = 0
    for (expected, actual) in results
        cost += (expected - actual)^2
    end
    return cost / length(results)
end

"""
function to run metropolis search algorithm. The main difference between this function and the enumerative search is that
it passes the examples to the enumerator.
"""
function metropolis_search(g::Grammars.ContextFreeGrammar, problem::Data.Problem, depth::Int, enumerator=StochasticSearchEnumerator) :: Expr
    symboltable :: SymbolTable = Grammars.SymbolTable(g)

    hypotheses = enumerator(grammar=g, examples=problem.examples, neighbourhood=constructNeighbourhood, propose=propose, accept=accept, temperature=temperature, cost_function=cost_function)

    for h :: RuleNode ∈ hypotheses
        # Create expression from rulenode representation of AST
        expr = Grammars.rulenode2expr(h, g)
        println(expr)
        # Evaluate examples the examples.
        #  `evaluate examples` returns as soon as it has found the first example that doesn't work.
        # if Evaluation.evaluate_examples(symboltable, expr, problem.examples)
        #     return expr
        # end
    end
end