function select_fitness_proportional_parents(population::Array{RuleNode}, fitness_array::Array{<:Real})::Tuple{RuleNode,RuleNode}
    sum_of_fitness = sum(fitness_array)
    fitness_array_normalized = [fitness_value / sum_of_fitness for fitness_value in fitness_array]
    parent1 = select_chromosome(population, fitness_array_normalized)
    parent2 = select_chromosome(population, fitness_array_normalized)
    return parent1, parent2
end

function select_two_random_parents(population::Array{RuleNode}, fitness_array::Array{<:Real})::Tuple{RuleNode,RuleNode}
    sum_of_fitness = sum(fitness_array)
    fitness_array_normalized = [fitness_value / sum_of_fitness for fitness_value in fitness_array]
    parent1 = select_chromosome(population, fitness_array_normalized)
    parent2 = select_chromosome(population, fitness_array_normalized)
    return parent1, parent2
end

function select_chromosome(population::Array{RuleNode}, fitness_array::Array{<:Real})::RuleNode
    random_number = rand()        
    current_fitness_sum = 0
    for (fitness_value, chromosome) in zip(fitness_array, population)
        # random number between 0 and 1
        current_fitness_sum += fitness_value
        if random_number < current_fitness_sum
            return chromosome
        end
    end 
    return population[end]  
end
