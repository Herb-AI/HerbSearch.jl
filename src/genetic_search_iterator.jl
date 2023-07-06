using Random

struct AlgorithmStateIsInvalid <: Exception
    message::String
end

Base.showerror(io::IO, e::AlgorithmStateIsInvalid) = print(io, e.message)


Base.@kwdef struct GeneticSearchIterator{FitnessFunction,CrossOverFunction,MutationFunction,SelectParentsFunction,EvaluationFunction} <: ExpressionIterator
    grammar::ContextSensitiveGrammar
    examples::Vector{<:Example}

    fitness::FitnessFunction
    cross_over::CrossOverFunction
    mutation!::MutationFunction
    select_parents::SelectParentsFunction # selects two parents to crossover
    evaluation_function::EvaluationFunction
    
    start_symbol::Symbol
    population_size::Int64
    mutation_probability::Float64
    maximum_initial_population_depth::Int64

    max_depth::Int64  = 10    # not used

end

struct GeneticIteratorState
    population::Array{RuleNode}
end

Base.IteratorSize(::GeneticSearchIterator) = Base.SizeUnknown()
Base.eltype(::GeneticSearchIterator) = RuleNode


"""
Validates that the iterator has valid paramaters set
"""
function validate_iterator(iter)
    if iter.population_size <= 0 
        throw(AlgorithmStateIsInvalid("The iterator population size: '$(iter.population_size)' should be > 0"))
    end
    if !hasmethod(iter.fitness, Tuple{RuleNode, Array{Tuple{Any,Any}}})
        throw(AlgorithmStateIsInvalid("The iterator fitness function should have two parameters: the program and an array with pair of tuples [(expected, value)]"))
    end
    if !hasmethod(iter.cross_over, Tuple{RuleNode, RuleNode})
        throw(AlgorithmStateIsInvalid(
            """The iterator select should get two paramaters:
                - parent1 :: RuleNode -> parent1 program 
                - parent2 :: RuleNode -> parent2 program 
                and return a list of children.
            """
        ))
    end

    if !hasmethod(iter.select_parents, Tuple{Array{RuleNode}, Array{<:Real}})
        throw(AlgorithmStateIsInvalid(
            """The iterator select should get two paramaters: 
                 - population: Array{RuleNode} -> array of programs
                 - fitness array:  Array{<:Number} -> array of fitness value for the population
                and return two rulenodes as the new parents.
            """))
    end
    return true
end

function get_best_program_and_fitness(population::Array{RuleNode}, iter:: GeneticSearchIterator)::RuleNode
    best_program = nothing
    best_fitness = 0
    for index ∈ eachindex(population)
        chromosome = population[index]
        fitness_value = iter.fitness(chromosome, calculate_cost_array(chromosome, iter.examples, iter.grammar, iter.evaluation_function))
        if isnothing(best_program) 
            best_fitness = fitness_value
            best_program = chromosome
        else 
            if fitness_value > best_fitness
                best_fitness = fitness_value
                best_program = chromosome
            end
        end
    end 
    return best_program
end
function Base.iterate(iter::GeneticSearchIterator)
    validate_iterator(iter)
    grammar = iter.grammar
    
    # sample a random node using start symbol and grammar
    population = Vector{RuleNode}(undef,iter.population_size)

    for i in 1:iter.population_size
        population[i] = rand(RuleNode, grammar, iter.start_symbol, iter.maximum_initial_population_depth)
    end 
    best_program = get_best_program_and_fitness(population, iter)
    return (best_program, GeneticIteratorState(population))
end


function Base.iterate(iter::GeneticSearchIterator, current_state::GeneticIteratorState)

    current_population = current_state.population

    # Calculate fitness
    fitness_array = [iter.fitness(chromosome, calculate_cost_array(chromosome, iter.examples, iter.grammar, iter.evaluation_function)) for chromosome in current_population]
    
    new_population = Vector{RuleNode}(undef,iter.population_size)

    # put the best program in the first slot of the population
    best_program = get_best_program_and_fitness(current_population, iter)
    new_population[begin] = best_program
    
    # do crossover
    index = 2
    while index <= iter.population_size
        parent1, parent2 = iter.select_parents(current_population, fitness_array)
        children = iter.cross_over(parent1, parent2)
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
    return (new_population[begin], GeneticIteratorState(new_population))
end


function calculate_cost_array(program::RuleNode, examples::Vector{<:Example}, grammar::Grammar, evaluation_function::Function)
    results = Tuple{<:Number,<:Number}[]
    expression = rulenode2expr(program, grammar)
    symbol_table = SymbolTable(grammar)
    for example ∈ filter(e -> e isa IOExample, examples)
        outcome = evaluation_function(symbol_table, expression, example.in)
        push!(results, (example.out, outcome))
    end
    return results
end
