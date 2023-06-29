function get_mh_enumerator(examples, cost_function, evaluation_function::Function=HerbEvaluation.test_with_input)
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

function get_vlsn_enumerator(examples, cost_function, enumeration_depth = 2, evaluation_function::Function=HerbEvaluation.test_with_input)
    return (grammar, max_depth, max_size, start_symbol) -> begin
        return StochasticSearchEnumerator(
            grammar=grammar,
            examples=examples,
            max_depth=max_depth,
            neighbourhood=constructNeighbourhoodRuleSubset,
            propose=enumerate_neighbours_propose(enumeration_depth),
            temperature=const_temperature,
            accept=best_accept,
            cost_function=cost_function,
            start_symbol=start_symbol,
            evaluation_function = evaluation_function,
        )
    end
end

function get_sa_enumerator(examples, cost_function, initial_temperature=1, temperature_decreasing_factor = 0.99, evaluation_function::Function=HerbEvaluation.test_with_input)
    return (grammar, max_depth, max_size, start_symbol) -> begin
        return StochasticSearchEnumerator(
            grammar=grammar,
            examples=examples,
            max_depth=max_depth,
            neighbourhood=constructNeighbourhoodRuleSubset,
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
