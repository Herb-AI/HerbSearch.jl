using Random


"""
MetropolisHastingsEnumerator(grammar::Grammar, max_depth::Int, sym::Symbol, examples::AbstractVector{Example}, neighbourhood::Function)
neighbourhood should be a function which takes two parameters: current program and grammar, and should return nodeLoc ...
An iterator over all possible expressions of a grammar up to max_depth with start symbol sym.
"""
Base.@kwdef mutable struct StochasticSearchEnumerator <: ExpressionIterator
    grammar::ContextFreeGrammar
    max_depth::Int = 5  # maximum depth of the program that is generated
    max_iterations::Int = 10000  # maximum number of iterations, after which the search stops
    examples::AbstractVector{Example}
    neighbourhood::Function
    propose::Function
    accept::Function
    temperature::Function
    cost_function::Function
    # sym::Symbol = :Real
end

Base.IteratorSize(::StochasticSearchEnumerator) = Base.SizeUnknown()
Base.eltype(::StochasticSearchEnumerator) = RuleNode

function Base.iterate(iter::StochasticSearchEnumerator)
    grammar, max_depth = iter.grammar, iter.max_depth
    node = rand(RuleNode, grammar, :Real, max_depth)
    return (deepcopy(node), node)
end

Base.@kwdef struct IteratorState
    current_program::RuleNode
    current_temperature::Float32
    current_num_iterations::Int
    best_program::RuleNode
    best_program_cost::Float32
end

function Base.iterate(iter::StochasticSearchEnumerator, current_state::IteratorState)
    if current_state.current_num_iterations == iter.max_iterations
        print(rulenode2expr(current_state.best_program))  # that's how we return best program for now; TODO: make more elegant
        return nothing
    end

    grammar, max_depth, IOexamples = iter.grammar, iter.max_depth, iter.ratio_correct_examples
    neighbourhood, propose, accept, temperature, cost_function = iter.neighbourhood, iter.propose, iter.accept, iter.temperature, iter.cost_function

    current_program = current_state.current_program

    neighbourhood_node_location, dict = neighbourhood(curr_expression, grammar)
    neighbourhood_symbol = return_type(grammar, get(current_program, neighbourhood_node_location))

    new_temperature = temperature(current_state.temperature)

    # propose new programs to consider
    programs_to_consider = propose(current_program, neighbourhood_node_location, neighbourhood_symbol, grammar, max_depth, dict)

    new_program = current_program
    current_cost = calculate_cost(program, cost_function, IOexamples, grammar)
    for program in programs_to_consider
        program_cost = calculate_cost(program, cost_function, IOexamples, grammar)
        if accept(current_program_cost, program_cost)
            new_program = program
            current_cost = program_cost
        end
    end

    if current_cost < current_state.best_program_cost
        next_state = IteratorState(
            current_program=new_program, 
            current_temperature=new_temperature,
            best_program=new_program, 
            best_program_cost=current_cost)
    else
        next_state = IteratorState(
            current_program=new_program, 
            current_temperature=new_temperature,
            best_program=current_state.best_program, 
            best_program_cost=current_state.best_program_cost)
    end

    return (new_program, next_state)
end

function calculate_cost(program::RuleNode, cost_function::Function, examples::AbstractVector{Example}, grammar::Grammar)
    results = Tuple{Any, Any}[]
    symbol_table = SymbolTable(grammar)
    for example ∈ filter(e -> e isa IOExample, examples)
        outcome = evaluate_with_input(symbol_table, program, example.in)
        push!(results, (example.out, outcome))
    end
    return cost_function(results)
end
