function get_genetic_enumerator(examples; 
    fitness_function = HerbSearch.default_fitness, 
    initial_population_size = 10,
    maximum_initial_population_depth = 3,
    mutation_probability = 0.1,
    cross_over = HerbSearch.crossover_swap_children_2,
    select_parents = HerbSearch.select_fitness_proportional_parents, 
    evaluation_function::Function=HerbEvaluation.test_with_input)
    return (grammar, max_depth, max_size, start_symbol) -> begin
        return GeneticSearchIterator(
            grammar = grammar,
            examples = examples,
            fitness = fitness_function,
            cross_over = cross_over,
            mutation! = random_mutate!,
            select_parents = select_parents,
            start_symbol = start_symbol,
            max_depth = max_depth,  
            population_size = initial_population_size,
            maximum_initial_population_depth = maximum_initial_population_depth,
            mutation_probability = mutation_probability,
            evaluation_function = evaluation_function
        )
    end

end

