using Random

struct AlgorithmStateIsInvalid <: Exception
    message::String
end

Base.showerror(io::IO, e::AlgorithmStateIsInvalid) = print(io, e.message)

"""
    GeneticSearchIterator{FitnessFunction,CrossOverFunction,MutationFunction,SelectParentsFunction,EvaluationFunction} <: ExpressionIterator

Defines an [`ExpressionIterator`](@ref) using genetic search. 

Consists of:

- `grammar::ContextSensitiveGrammar`: the grammar to search over
- `examples::Vector{<:IOExample}`: a collection of examples defining the specification 

- `fitness::FitnessFunction`: assigns a numerical value (fitness score) to each individual based on how closely it meets the desired objective
- `cross_over::CrossOverFunction`: combines the program from two parent individuals to create one or more offspring individuals
- `mutation!::MutationFunction`: mutates the program of an invididual
- `select_parents::SelectParentsFunction`: selects two parents for the crossover
- `evaluation_function::EvaluationFunction`: interpreter to evaluate the individual programs
- `start_symbol::Symbol`: defines the start symbol from which the search should be started
- `population_size::Int64`: number of inviduals in the population
- `mutation_probability::Float64`: probability of mutation for each individual
- `maximum_initial_population_depth::Int64`: maximum depth of trees when population is initialized 

end
"""
Base.@kwdef struct GeneticSearchIterator{FitnessFunction,CrossOverFunction,MutationFunction,SelectParentsFunction,EvaluationFunction} <: ExpressionIterator
    grammar::ContextSensitiveGrammar
    examples::Vector{<:IOExample}

    fitness::FitnessFunction
    cross_over::CrossOverFunction
    mutation!::MutationFunction
    select_parents::SelectParentsFunction # selects two parents to crossover
    evaluation_function::EvaluationFunction
    start_symbol::Symbol
    population_size::Int64
    mutation_probability::Float64
    maximum_initial_population_depth::Int64

end

struct GeneticIteratorState
    population::Array{RuleNode}
end

Base.IteratorSize(::GeneticSearchIterator) = Base.SizeUnknown()
# TODO: Document the fact that the iterator returns the best program and the fitness function for the current population.
Base.eltype(::GeneticSearchIterator) = (RuleNode, Real)


"""
    validate_iterator(iter)

Validates the parameters of the iterator
"""
function validate_iterator(iter)
    if iter.population_size <= 0
        throw(AlgorithmStateIsInvalid("The iterator population size: '$(iter.population_size)' should be > 0"))
    end
    if !hasmethod(iter.fitness, Tuple{RuleNode,Array{Tuple{Any,Any}}})
        throw(AlgorithmStateIsInvalid("The iterator fitness function should have two parameters: the program and an array with pair of tuples [(expected, value)]"))
    end
    if !hasmethod(iter.cross_over, Tuple{RuleNode,RuleNode,Grammar})
        throw(AlgorithmStateIsInvalid(
            """The iterator crossover function should get two parameters:
                - parent1 :: RuleNode -> parent1 program 
                - parent2 :: RuleNode -> parent2 program 
                and return a list of children.
            """
        ))
    end

    if !hasmethod(iter.select_parents, Tuple{Array{RuleNode},Array{<:Real}})
        throw(AlgorithmStateIsInvalid(
            """The iterator select_parent function should get two paramaters: 
                 - population: Array{RuleNode} -> array of programs
                 - fitness array:  Array{<:Number} -> array of fitness value for the population
                and return two rulenodes as the new parents.
            """))
    end
    return true
end

"""
    get_best_program(population::Array{RuleNode}, iter:: GeneticSearchIterator)

Returns the best program within the population with respect to the fitness function.
"""
function get_best_program(population::Array{RuleNode}, iter::GeneticSearchIterator)
    best_program = population[begin]
    best_fitness = 0
    lk = ReentrantLock()
    Threads.@threads for index ∈ eachindex(population)
        chromosome = population[index]
        fitness_value = iter.fitness(chromosome, HerbInterpret.evaluate_program(chromosome, iter.examples, iter.grammar, iter.evaluation_function))
        lock(lk) do
            if fitness_value > best_fitness
                best_fitness = fitness_value
                best_program = chromosome
            end
        end
    end
    return best_program, best_fitness
end

"""
    Base.iterate(iter::GeneticSearchIterator)

Iterates the search space using a genetic algorithm. First generates a population sampling random programs. Returns the best program-so-far, and the state of the iterator.
"""
function Base.iterate(iter::GeneticSearchIterator)
    validate_iterator(iter)
    grammar = iter.grammar

    population = Vector{RuleNode}(undef, iter.population_size)

    for i in 1:iter.population_size
        # sample a random nodes using start symbol and grammar
        population[i] = rand(RuleNode, grammar, iter.start_symbol, iter.maximum_initial_population_depth)
    end
    best_program, best_fitness = get_best_program(population, iter)
    return ((best_program, best_fitness), GeneticIteratorState(population))
end


"""
    Base.iterate(iter::GeneticSearchIterator, current_state::GeneticIteratorState)

Iterates the search space using a genetic algorithm. Takes the iterator and the current state to mutate and crossover random inviduals. Returns the best program-so-far and the state of the iterator.
"""
function Base.iterate(iter::GeneticSearchIterator, current_state::GeneticIteratorState)

    current_population = current_state.population

    # Calculate fitness and best program
    fitness_array = Vector{Float64}(undef, iter.population_size)
    best_program = current_population[begin]
    best_fitness = 0

    lk = ReentrantLock()
    Threads.@threads for i in 1:iter.population_size
        chromosome = current_population[i]
        fitness_array[i] = iter.fitness(chromosome, HerbInterpret.evaluate_program(chromosome, iter.examples, iter.grammar, iter.evaluation_function))
        lock(lk) do 
            if fitness_array[i] > best_fitness 
                best_fitness = fitness_array[i]
                best_program = chromosome
            end
        end
    end

    new_population = Vector{RuleNode}(undef, iter.population_size)
    new_population[begin] = best_program

    # do crossover
    index = 2
    while index <= iter.population_size
        parent1, parent2 = iter.select_parents(current_population, fitness_array)
        children = iter.cross_over(parent1, parent2, iter.grammar)
        for child ∈ children
            if index > iter.population_size
                break
            end
            new_population[index] = child
            index += 1
        end
    end
    # Do mutation 
    for chromosome in new_population
        random_number = rand()
        if random_number < iter.mutation_probability
            iter.mutation!(chromosome, iter.grammar)
        end
    end

    # TODO: Maybe recompute the best program after the cross_over + mutation and then return it.

    # return the best program before any cross over or mutation and the fitness corresponding to that program
    return ((best_program, best_fitness), GeneticIteratorState(new_population))
end

