"""
    get_mh_enumerator(examples::AbstractArray{<:Example}, cost_function::Function, evaluation_function::Function=HerbInterpret.test_with_input)

Returns an enumerator that runs according to the Metropolis Hastings algorithm.
- `examples` : array of examples
- `cost_function` : cost function to evaluate the programs proposed
- `evaluation_function` : evaluation function that evaluates the program generated and produces an output 
The propose function is random_fill_propose and the accept function is probabilistic.
The temperature value of the algorithm remains constant over time. 
"""
function get_mh_enumerator(examples::AbstractArray{<:Example}, cost_function::Function, evaluation_function::Function=HerbInterpret.test_with_input)
    return (grammar, max_depth, max_size, start_symbol) -> begin
        return StochasticSearchEnumerator(
            grammar=grammar,
            examples=examples,
            max_depth=max_depth,
            neighbourhood=constructNeighbourhood,
            propose=random_fill_propose,
            temperature=const_temperature,
            accept=probabilistic_accept,
            cost_function=cost_function,
            start_symbol=start_symbol,
            evaluation_function=evaluation_function,
        )
    end

end

"""
    get_vlsn_enumerator(examples, cost_function, enumeration_depth = 2, evaluation_function::Function=HerbInterpret.test_with_input)

Returns an enumerator that runs according to the Very Large Scale Neighbourhood Search algorithm.
- `examples` : array of examples
- `cost_function` : cost function to evaluate the programs proposed
- `enumeration_depth` : the enumeration depth to search for a best program at a time
- `evaluation_function` : evaluation function that evaluates the program generated and produces an output 
The propose function consists of all possible programs of the given `enumeration_depth`. The accept function accepts the program
with the lowest cost according to the `cost_function`.
The temperature value of the algorithm remains constant over time. 
"""
function get_vlsn_enumerator(examples, cost_function, enumeration_depth = 2, evaluation_function::Function=HerbInterpret.test_with_input)
    return (grammar, max_depth, max_size, start_symbol) -> begin
        return StochasticSearchEnumerator(
            grammar=grammar,
            examples=examples,
            max_depth=max_depth,
            neighbourhood=constructNeighbourhood,
            propose=enumerate_neighbours_propose(enumeration_depth),
            temperature=const_temperature,
            accept=best_accept,
            cost_function=cost_function,
            start_symbol=start_symbol,
            evaluation_function = evaluation_function, 
        )
    end
end

"""
    get_sa_enumerator(examples, cost_function, initial_temperature=1, temperature_decreasing_factor = 0.99, evaluation_function::Function=HerbInterpret.test_with_input)

Returns an enumerator that runs according to the Very Large Scale Neighbourhood Search algorithm.
- `examples` : array of examples
- `cost_function` : cost function to evaluate the programs proposed
- `initial_temperature` : the starting temperature of the algorithm
- `temperature_decreasing_factor` : the decreasing factor of the temperature of the time
- `evaluation_function` : evaluation function that evaluates the program generated and produces an output 
The propose function is `random_fill_propose` (the same as for Metropolis Hastings). The accept function is probabilistic
but takes into account the tempeerature too.
"""
function get_sa_enumerator(examples, cost_function, initial_temperature=1, temperature_decreasing_factor = 0.99, evaluation_function::Function=HerbInterpret.test_with_input)
    return (grammar, max_depth, max_size, start_symbol) -> begin
        return StochasticSearchEnumerator(
            grammar=grammar,
            examples=examples,
            max_depth=max_depth,
            neighbourhood=constructNeighbourhood,
            propose=random_fill_propose,
            temperature=decreasing_temperature(temperature_decreasing_factor),
            accept=probabilistic_accept_with_temperature,
            cost_function=cost_function,
            start_symbol=start_symbol,
            initial_temperature=initial_temperature,
            evaluation_function = evaluation_function,
        )
    end
end
