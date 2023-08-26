using Random

"""
StochasticSearchEnumerator

A unified struct for the algorithms Metropolis Hastings, Very Large Scale Neighbourhood and Simulated Annealing.
Each algorithm implements `neighbourhood` `propose` `accept` and `temperature` functions. Below the signiture of all this function is shown

## Signatures
---
Returns a node location from the program that is the neighbourhood. It can also return other information using  `dict`

    neighbourhood(program::RuleNode, grammar::Grammar) -> (loc::NodeLocation, dict::Dict)
---
Proposes a list of programs using the location provided by `neighbourhood` and the `dict`.
    
    propose(current_program, loc::NodeLocation, grammar::Grammar, max_depth::Int64, dict::Dict) -> Iter[RuleNode]
----

Based on the current program and possible cost and temperature it accepts the program or not. Usually we would always want to accept
better programs but we might get stuck if we do so. That is why some implementations of the `accept` function accept with a probability 
costs that are worse. 
`cost` means how different are the outcomes of the program compared to the correct outcomes.
The lower the `cost` the better the program performs on the examples. The `cost` is provided by the `cost_function`

    accept(current_cost::Real, possible_cost::Real, temperature::Real) -> Bool
----
Returns the new temperature based on the previous temperature. Higher the `temperature` means that the algorithm will explore more.
    
    temperature(previous_temperature::Real) -> Real 
---
Returns the cost of the current program. It receives a list of tuples `(expected, found)` and gives back a cost.
    
    cost_function(outcomes::Tuple{<:Number,<:Number}[]) -> Real

----
# Fields
-   `grammar::ContextSensitiveGrammar` grammar that the algorithm uses
-   `max_depth::Int64 = 5`  maximum depth of the program to generate
-   `examples::Vector{<:Example}` example used to check the program
-   `neighbourhood::Function` 
-   `propose::Function`
-   `accept::Function`
-   `temperature::Function`
-   `cost_function::Function`
-   `start_symbol::Symbol` the start symbol of the algorithm `:Real` or `:Int`
-   `initial_temperature::Real` = 1 
-   `evaluation_function`::Function that evaluates the julia expressions
An iterator over all possible expressions of a grammar up to max_depth with start symbol sym.
Parameterized StochasticSearchEnumerator based on the all the functions. This helps the performance.
Using the type ::Function leads to poor compile performance. 
Read https://discourse.julialang.org/t/how-to-enforce-function-signature-type-on-a-struct/101211/2
"""
Base.@kwdef mutable struct StochasticSearchEnumerator{A,B,C,D,E,F} <: ExpressionIterator
    grammar::ContextSensitiveGrammar
    max_depth::Int64 = 5  # maximum depth of the program that is generated
    examples::Vector{<:Example}
    neighbourhood::A
    propose::B
    accept::C
    temperature::D
    cost_function::E
    start_symbol::Symbol
    initial_temperature::Real = 1
    evaluation_function::F
end

Base.@kwdef struct IteratorState
    current_program::RuleNode
    current_temperature::Real = 1
end

Base.IteratorSize(::StochasticSearchEnumerator) = Base.SizeUnknown()
Base.eltype(::StochasticSearchEnumerator) = RuleNode

function Base.iterate(iter::StochasticSearchEnumerator)
    grammar, max_depth = iter.grammar, iter.max_depth
    # sample a random node using start symbol and grammar
    sampled_program = rand(RuleNode, grammar, iter.start_symbol, max_depth)
    return (sampled_program, IteratorState(
        current_program=sampled_program,
        current_temperature=iter.initial_temperature))
end


"""
The algorithm that constructs the iterator of StochasticSearchEnumerator. It has the following structure:

1. get a random node location -> location,dict = neighbourhood(current_program)
2. call propose on the current program getting a list of possbile replacements in the node location 
3. iterate through all the possible replacements and perform the replacement in the current program 
    4.  accept the new program by modifying the next_program or reject the new program
5. return the new next_program
"""
function Base.iterate(iter::StochasticSearchEnumerator, current_state::IteratorState)
    grammar, examples = iter.grammar, iter.examples
    current_program = current_state.current_program
    
    current_cost = calculate_cost(current_program, iter.cost_function, examples, grammar, iter.evaluation_function)

    new_temperature = iter.temperature(current_state.current_temperature)

    # get the neighbour node location 
    neighbourhood_node_location, dict = iter.neighbourhood(current_state.current_program, grammar)

    # get the subprogram pointed by node-location
    subprogram = get(current_program, neighbourhood_node_location)


    @info "Start: $(rulenode2expr(current_program, grammar)), subexpr: $(rulenode2expr(subprogram, grammar)), cost: $current_cost
            temp $new_temperature"

    # propose new programs to consider. They are programs to put in the place of the node
    possible_replacements = iter.propose(current_program, neighbourhood_node_location, grammar, iter.max_depth, dict)
    
    # the next program in the iteration
    next_program = deepcopy(current_program)
    possible_program = current_program
    best_replacement = nothing
    for possible_replacement in possible_replacements
        # replace node at node_location with new_random 
        if neighbourhood_node_location.i == 0
            possible_program = possible_replacement
        else
            # update current_program with the subprogram generated
            # this line mutates also the current_program. That is why we deepcopy at 115
            neighbourhood_node_location.parent.children[neighbourhood_node_location.i] = possible_replacement
        end
        program_cost = calculate_cost(possible_program, iter.cost_function, examples, grammar, iter.evaluation_function)
        if iter.accept(current_cost, program_cost, new_temperature) 
            next_program = deepcopy(possible_program)
            current_cost = program_cost
            best_replacement = deepcopy(possible_replacement)
        end
    end

    next_state = IteratorState(
        current_program=next_program,
        current_temperature=new_temperature)

    return (next_program, next_state)
end

"""
Returns the cost of the `program` using the examples and the `cost_function`. It first convert the program to an expression and
evaluates it on all the examples.
"""
function calculate_cost(program::RuleNode, cost_function::Function, examples::Vector{<:Example}, grammar::Grammar, evaluation_function::Function)
    results = Tuple{<:Number,<:Number}[]
    expression = rulenode2expr(program, grammar)
    symbol_table = SymbolTable(grammar)
    for example ∈ filter(e -> e isa IOExample, examples)
        outcome = evaluation_function(symbol_table, expression, example.in)
        push!(results, (example.out, outcome))
    end
    return cost_function(results)
end
