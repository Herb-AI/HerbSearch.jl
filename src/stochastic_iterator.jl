using Random

# """
#     Base.@kwdef struct StochasticSearchIterator <: ProgramIterator

# A unified struct for the algorithms Metropolis Hastings, Very Large Scale Neighbourhood and Simulated Annealing.
# Each algorithm implements `neighbourhood` `propose` `accept` and `temperature` functions. Below the signiture of all this function is shown

# ## Signatures
# ---
# Returns a node location from the program that is the neighbourhood. It can also return other information using  `dict`

#     neighbourhood(program::RuleNode, grammar::Grammar) -> (loc::NodeLocation, dict::Dict)
# ---
# Proposes a list of programs using the location provided by `neighbourhood` and the `dict`.
    
#     propose(current_program, loc::NodeLocation, grammar::Grammar, max_depth::Int64, dict::Dict) -> Iter[RuleNode]
# ----

# Based on the current program and possible cost and temperature it accepts the program or not. Usually we would always want to accept
# better programs but we might get stuck if we do so. That is why some implementations of the `accept` function accept with a probability 
# costs that are worse. 
# `cost` means how different are the outcomes of the program compared to the correct outcomes.
# The lower the `cost` the better the program performs on the examples. The `cost` is provided by the `cost_function`

#     accept(current_cost::Real, possible_cost::Real, temperature::Real) -> Bool
# ----
# Returns the new temperature based on the previous temperature. Higher the `temperature` means that the algorithm will explore more.
    
#     temperature(previous_temperature::Real) -> Real 
# ---
# Returns the cost of the current program. It receives a list of tuples `(expected, found)` and gives back a cost.
    
#     cost_function(outcomes::Tuple{<:Number,<:Number}[]) -> Real

# ----
# # Fields
# -   `grammar::ContextSensitiveGrammar` grammar that the algorithm uses
# -   `max_depth::Int64 = 5`  maximum depth of the program to generate
# -   `examples::Vector{Example}` example used to check the program
# -   `neighbourhood::Function` 
# -   `propose::Function`
# -   `accept::Function`
# -   `temperature::Function`
# -   `cost_function::Function`
# -   `start_symbol::Symbol` the start symbol of the algorithm `:Real` or `:Int`
# -   `initial_temperature::Real` = 1 
# -   `evaluation_function`::Function that evaluates the julia expressions
# An iterator over all possible expressions of a grammar up to max_depth with start symbol sym.
# """
# Base.@kwdef struct StochasticSearchIterator <: ProgramIterator
#     grammar::ContextSensitiveGrammar
#     max_depth::Int64 = 5  # maximum depth of the program that is generated
#     examples::Vector{Example}
#     neighbourhood::Function
#     propose::Function
#     accept::Function
#     temperature::Function
#     cost_function::Function
#     start_symbol::Symbol
#     initial_temperature::Real = 1
#     evaluation_function::Function
# end

"""
    mutable struct StochasticSearchIterator <: ProgramIterator

A program iterator using a [`StochasticSearchStrategy`](@ref) over all possible expressions of a `grammar` with start symbol `sym`.
"""
mutable struct StochasticSearchIterator <: ProgramIterator
    search_strategy::TopDownSearchStrategy
    grammar::Grammar
    sym::Symbol
    max_depth::Int
    max_size::Int
    max_time::Int
    max_enumerations::Int
end

function StochasticSearchIterator(search_strategy::StochasticSearchStrategy, grammar::Grammar, sym::Symbol; max_depth::Int=typemax(Int), max_size::Int=typemax(Int), max_time::Int=typemax(Int), max_enumerations::Int=typemax(Int))
    return StochasticSearchIterator(search_strategy, grammar, sym, max_depth, max_size, max_time, max_enumerations)
end

struct IteratorState
    current_program::RuleNode
    current_temperature::Real
    dmap::AbstractVector{Int} # depth map of each rule
end

Base.IteratorSize(::StochasticSearchIterator) = Base.SizeUnknown()
Base.eltype(::StochasticSearchIterator) = RuleNode

function Base.iterate(iter::StochasticSearchIterator)
    grammar, max_depth, search_strategy = iter.grammar, iter.max_depth, iter.search_strategy
    # sample a random node using start symbol and grammar
    dmap = mindepth_map(grammar)
    sampled_program = rand(RuleNode, grammar, iter.start_symbol, max_depth)

    #todo: states information is no longer in the iter, this should be refactored to the search_strategy
    return (sampled_program, IteratorState(sampled_program, iter.initial_temperature,dmap))  
end


"""
    Base.iterate(iter::StochasticSearchIterator, current_state::IteratorState)

The algorithm that constructs the iterator of StochasticSearchIterator. It has the following structure:

1. get a random node location -> location,dict = neighbourhood(current_program)
2. call propose on the current program getting a list of possbile replacements in the node location 
3. iterate through all the possible replacements and perform the replacement in the current program 
    4.  accept the new program by modifying the next_program or reject the new program
5. return the new next_program
"""
function Base.iterate(iter::StochasticSearchIterator, current_state::IteratorState)
    grammar, examples, search_strategy = iter.grammar, iter.examples, iter.search_strategy
    current_program = current_state.current_program
    
    current_cost = calculate_cost(current_program, iter.cost_function, examples, grammar, iter.evaluation_function)

    new_temperature = iter.temperature(current_state.current_temperature)

    # get the neighbour node location 
    neighbourhood_node_location, dict = iter.neighbourhood(current_state.current_program, grammar)

    # get the subprogram pointed by node-location
    subprogram = get(current_program, neighbourhood_node_location)


    @info "Start: $(rulenode2expr(current_program, grammar)), subexpr: $(rulenode2expr(subprogram, grammar)), cost: $current_cost
            temp $new_temperature"

    # propose new programs to consider. They are programs to put in the place of the nodelocation
    possible_replacements = iter.propose(current_program, neighbourhood_node_location, grammar, iter.max_depth, current_state.dmap, dict)
    
    next_program = get_next_program(current_program, possible_replacements, neighbourhood_node_location, new_temperature, iter, current_cost)
    next_state = IteratorState(next_program,new_temperature,current_state.dmap)
    return (next_program, next_state)
end


function get_next_program(current_program::RuleNode, possible_replacements, neighbourhood_node_location::NodeLoc, new_temperature, iter::StochasticSearchIterator, current_cost)
    next_program = deepcopy(current_program)
    possible_program = current_program
    for possible_replacement in possible_replacements
        # replace node at node_location with possible_replacement 
        if neighbourhood_node_location.i == 0
            possible_program = possible_replacement
        else
            # update current_program with the subprogram generated
            neighbourhood_node_location.parent.children[neighbourhood_node_location.i] = possible_replacement
        end
        program_cost = calculate_cost(possible_program, iter.cost_function, iter.examples, iter.grammar, iter.evaluation_function)
        if iter.accept(current_cost, program_cost, new_temperature) 
            next_program = deepcopy(possible_program)
            current_cost = program_cost
        end
    end
    return next_program

end

"""
    calculate_cost(program::RuleNode, cost_function::Function, examples::AbstractVector{Example}, grammar::Grammar, evaluation_function::Function)

Returns the cost of the `program` using the examples and the `cost_function`. It first convert the program to an expression and
evaluates it on all the examples using [`HerbInterpret.evaluate_program`](@ref).
"""
function calculate_cost(program::RuleNode, cost_function::Function, examples::AbstractVector{Example}, grammar::Grammar, evaluation_function::Function)
    results = HerbInterpret.evaluate_program(program,examples,grammar,evaluation_function)
    return cost_function(results)
end
