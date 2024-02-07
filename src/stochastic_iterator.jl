using Random

 """
     abstract type StochasticSearchIterator <: ProgramIterator

 A unified abstract type for the algorithms Metropolis Hastings, Very Large Scale Neighbourhood and Simulated Annealing. 
 Each algorithm implements `neighbourhood`, `propose`, `accept` and `temperature` functions. Below the signatures of each function is shown.

 ## Signatures
 ---
 Returns a node location from the program that is the neighbourhood. It can also return other information using  `dict`

    neighbourhood(iter::T, current_program::RuleNode) where T <: StochasticSearchIterator -> (loc::NodeLocation, dict::Dict)
 ---
 Proposes a list of programs using the location provided by `neighbourhood` and the `dict`.
   
     propose(iter::T, current_program::RuleNode, neighbourhood_node_loc::NodeLoc, dmap::AbstractVector{Int}, dict::Union{Nothing,Dict{String,Any}}) where T <: StochasticSearchIterator -> Iter[RuleNode]
 ----

 Based on the current program and possible cost and temperature it accepts the program or not. Usually we would always want to accept
 better programs but we might get stuck if we do so. That is why some implementations of the `accept` function accept with a probability 
 costs that are worse. 
 `cost` means how different are the outcomes of the program compared to the correct outcomes.
 The lower the `cost` the better the program performs on the examples. The `cost` is provided by the `cost_function`

    accept(::T, current_cost::Real, next_cost::Real, temperature::Real) where T <: StochasticSearchIterator -> Bool
 ----
 Returns the new temperature based on the previous temperature. Higher the `temperature` means that the algorithm will explore more.
   
    temperature(::T, current_temperature::Real) where T <: StochasticSearchIterator -> Real
 ---
 Returns the cost of the current program. It receives a list of tuples `(expected, found)` and gives back a cost.
   
     cost_function(outcomes::Tuple{<:Number,<:Number}[]) -> Real

 ----
 # Fields
 -   `grammar::ContextSensitiveGrammar` grammar that the algorithm uses
 -   `sym::Symbol` the start symbol of the algorithm `:Real` or `:Int`

 -   `examples::Vector{IOExample}` example used to check the program
 -   `cost_function::Function`
 -   `initial_temperature::Real` = 1 
 -   `evaluation_function`::Function that evaluates the julia expressions
 An iterator over all possible expressions of a grammar up to max_depth with start symbol sym. Also inherits all stop criteria like `max_depth` from `ProgramIterator`.
 """
abstract type StochasticSearchIterator <: ProgramIterator end

struct IteratorState
    current_program::RuleNode
    current_temperature::Real
    dmap::AbstractVector{Int} # depth map of each rule
end

Base.IteratorSize(::StochasticSearchIterator) = Base.SizeUnknown()
Base.eltype(::StochasticSearchIterator) = RuleNode

function Base.iterate(iter::StochasticSearchIterator)
    grammar, max_depth = iter.grammar, iter.max_depth
    # sample a random node using start symbol and grammar
    dmap = mindepth_map(grammar)
    sampled_program = rand(RuleNode, grammar, iter.sym, max_depth)

    return (sampled_program, IteratorState(sampled_program, iter.initial_temperature,dmap))  
end


"""
    Base.iterate(iter::StochasticSearchIterator, current_state::IteratorState)

The algorithm that constructs the iterator of StochasticSearchIterator. It has the following structure:

1. get a random node location -> location,dict = neighbourhood(current_program)
2. call propose on the current program getting a list of possbile replacements in the node location 
3. iterate through all the possible replacements and perform the replacement in the current program 
4. accept the new program by modifying the next_program or reject the new program
5. return the new next_program
"""
function Base.iterate(iter::StochasticSearchIterator, current_state::IteratorState)
    grammar, examples = iter.grammar, iter.spec
    current_program = current_state.current_program
    
    current_cost = calculate_cost(iter, current_program)

    new_temperature = temperature(iter, current_state.current_temperature)

    # get the neighbour node location 
    neighbourhood_node_location, dict = neighbourhood(iter, current_state.current_program)

    # get the subprogram pointed by node-location
    subprogram = get(current_program, neighbourhood_node_location)


    @info "Start: $(rulenode2expr(current_program, grammar)), subexpr: $(rulenode2expr(subprogram, grammar)), cost: $current_cost
            temp $new_temperature"

    # propose new programs to consider. They are programs to put in the place of the nodelocation
    possible_replacements = propose(iter, current_program, neighbourhood_node_location, current_state.dmap, dict)
    
    next_program = get_next_program(iter, current_program, possible_replacements, neighbourhood_node_location, new_temperature, current_cost)
    next_state = IteratorState(next_program,new_temperature,current_state.dmap)
    return (next_program, next_state)
end


function get_next_program(iter::StochasticSearchIterator, current_program::RuleNode, possible_replacements, neighbourhood_node_location::NodeLoc, new_temperature, current_cost)
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
        program_cost = calculate_cost(iter, possible_program)
        if accept(iter, current_cost, program_cost, new_temperature) 
            next_program = deepcopy(possible_program)
            current_cost = program_cost
        end
    end
    return next_program

end

"""
    _calculate_cost(program::RuleNode, cost_function::Function, spec::AbstractVector{IOExample}, grammar::Grammar, evaluation_function::Function)

Returns the cost of the `program` using the examples and the `cost_function`. It first convert the program to an expression and evaluates it on all the examples.
"""
function _calculate_cost(program::RuleNode, cost_function::Function, spec::AbstractVector{IOExample}, grammar::Grammar, evaluation_function::Function)
    results = Tuple{<:Number,<:Number}[]

    expression = rulenode2expr(program, grammar)
    symbol_table = SymbolTable(grammar)

    for example ∈ filter(e -> e isa IOExample, spec)
        outcome = evaluation_function(symbol_table, expression, example.in)
        push!(results, (example.out, outcome))
    end

    return cost_function(results)
end

"""
    calculate_cost(iter::T, program::RuleNode) where T <: StochasticSearchIterator

Wrapper around [`_calculate_cost`](@ref).
"""
calculate_cost(iter::T, program::RuleNode) where T <: StochasticSearchIterator = _calculate_cost(program, iter.cost_function, iter.spec, iter.grammar, iter.evaluation_function)

neighbourhood(iter::T, current_program::RuleNode) where T <: StochasticSearchIterator = constructNeighbourhood(current_program, iter.grammar)

Base.@doc """
    MHSearchIterator(examples::AbstractArray{<:IOExample}, cost_function::Function, evaluation_function::Function=HerbInterpret.execute_on_input)

Returns an enumerator that runs according to the Metropolis Hastings algorithm.
- `spec` : array of examples
- `cost_function` : cost function to evaluate the programs proposed
- `evaluation_function` : evaluation function that evaluates the program generated and produces an output
The propose function is random_fill_propose and the accept function is probabilistic.
The temperature value of the algorithm remains constant over time.
""" MHSearchIterator

@programiterator MHSearchIterator(
    spec::Vector{<:IOExample},
    cost_function::Function,
    initial_temperature::Real = 1,
    evaluation_function::Function = execute_on_input, 
) <: StochasticSearchIterator

propose(iter::MHSearchIterator, current_program::RuleNode, neighbourhood_node_loc::NodeLoc, dmap::AbstractVector{Int}, dict::Union{Nothing,Dict{String,Any}}) = random_fill_propose(current_program, neighbourhood_node_loc, iter.grammar, iter.max_depth, dmap, dict)

temperature(::MHSearchIterator, current_temperature::Real) = const_temperature(current_temperature)

accept(::MHSearchIterator, current_cost::Real, next_cost::Real, temperature::Real) = probabilistic_accept(current_cost, next_cost, temperature)

Base.@doc """
    VLSNSearchIterator(spec, cost_function, enumeration_depth = 2, evaluation_function::Function=HerbInterpret.execute_on_input) = StochasticSearchIterator(

Returns an iterator that runs according to the Very Large Scale Neighbourhood Search algorithm.
- `spec` : array of examples
- `cost_function` : cost function to evaluate the programs proposed
- `vlsn_neighbourhood_depth` : the enumeration depth to search for a best program at a time
- `evaluation_function` : evaluation function that evaluates the program generated and produces an output
The propose function consists of all possible programs of the given `enumeration_depth`. The accept function accepts the program
with the lowest cost according to the `cost_function`.
The temperature value of the algorithm remains constant over time.
""" VLSNSearchIterator
@programiterator VLSNSearchIterator(
    spec::Vector{<:IOExample},
    cost_function::Function,
    vlsn_neighbourhood_depth::Int = 2,
    initial_temperature::Real = 1,
    evaluation_function::Function = execute_on_input
) <: StochasticSearchIterator

propose(iter::VLSNSearchIterator, current_program::RuleNode, neighbourhood_node_loc::NodeLoc, dmap::AbstractVector{Int}, dict::Union{Nothing,Dict{String,Any}}) = enumerate_neighbours_propose(iter.vlsn_neighbourhood_depth)(current_program, neighbourhood_node_loc, iter.grammar, iter.max_depth, dmap, dict)

temperature(::VLSNSearchIterator, current_temperature::Real) = const_temperature(current_temperature)

accept(::VLSNSearchIterator, current_cost::Real, next_cost::Real, temperature::Real) = best_accept(current_cost, next_cost, temperature)


Base.@doc """
    SASearchIterator(spec, cost_function, initial_temperature=1, temperature_decreasing_factor = 0.99, evaluation_function::Function=HerbInterpret.execute_on_input)

Returns an enumerator that runs according to the Simulated Annealing Search algorithm.
- `spec` : array of examples
- `cost_function` : cost function to evaluate the programs proposed
- `initial_temperature` : the starting temperature of the algorithm
- `temperature_decreasing_factor` : the decreasing factor of the temperature of the time
- `evaluation_function` : evaluation function that evaluates the program generated and produces an output
The propose function is `random_fill_propose` (the same as for Metropolis Hastings). The accept function is probabilistic
but takes into account the tempeerature too.
""" SASearchIterator
@programiterator SASearchIterator(
    spec::Vector{<:IOExample},
    cost_function::Function,
    initial_temperature::Real = 1,
    temperature_decreasing_factor::Real = 0.99,
    evaluation_function::Function = execute_on_input
) <: StochasticSearchIterator

propose(iter::SASearchIterator, current_program::RuleNode, neighbourhood_node_loc::NodeLoc, dmap::AbstractVector{Int}, dict::Union{Nothing,Dict{String,Any}}) = random_fill_propose(current_program, neighbourhood_node_loc, iter.grammar, iter.max_depth, dmap, dict)

temperature(iter::SASearchIterator, current_temperature::Real) = decreasing_temperature(iter.temperature_decreasing_factor)(current_temperature)

accept(::SASearchIterator, current_cost::Real, next_cost::Real, temperature::Real) = probabilistic_accept_with_temperature(current_cost, next_cost, temperature)


