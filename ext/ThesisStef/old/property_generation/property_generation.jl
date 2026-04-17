#=

-=-=-=-=- Property creation -=-=-=-=-

Given task (X_1, X_2, ...) -> O_t

Set F as the first N programs from BFS iterator with observational equivalance
Outputs are labbeled O_i

Initialize set P_c of candidate properties as empty

Maintain a set V of lists of values that are produced by properties

For property p in BFS iterator with limit of N:

    Compute values V_t = p(o_t, x_1, x_2) for each concrete I/O example

    Discard p if V contains any false value

    Compute list of values V_i = p(o_i, x_1, x_2) for each concrete I/candidate O example

    Discard p if V_i is in V

    Add p to P_c

    Add V_i to V


-=-=-=-=- Property selection -=-=-=-=-

Intialize set P of selected properties as empty

Recall V is a set which has an entry for each program that contains the list of values produced for each property

While V is not empty:

    find the property p that yields at least one false for the most programs

    add property p to P

    remove the program values from V that produced at least one false on property p

=#


function generate_properties(;
    grammar,
    property_grammar,
    interpreter,
    inputs,
    target_outputs,
    output_type,
    boolean_type,
    max_property_size,
    max_program_size,
    max_number_of_properties,
    ideal_prune_ratio,
)
    seen_outputs = generate_programs(
        grammar = grammar,
        interpreter = interpreter,
        target_outputs = target_outputs,
        output_type = output_type,
        max_program_size = max_program_size,
    )
 
    properties, values_per_property, = create_properties(
        seen_outputs = seen_outputs,
        property_grammar = property_grammar,
        interpreter = interpreter,
        inputs = inputs,
        target_outputs = target_outputs,
        output_type = output_type,
        boolean_type = boolean_type,
        max_property_size = max_property_size,
    )

    selected_properties = select_properties(
        properties = properties,
        values_per_property = values_per_property,
        property_grammar = property_grammar,
        max_number_of_properties = max_number_of_properties,  
        ideal_prune_ratio = ideal_prune_ratio 
    )
    
    return selected_properties
end

function generate_programs(;
    grammar,
    interpreter,
    target_outputs,
    output_type,
    max_program_size,    
)
    grammar_tags = get_relevant_tags(grammar)

    # for (r, v) in grammar_tags
    #     if v == :_arg_3
    #         addconstraint!(grammar, Contains(r))
    #     end
    # end

    # Create the outputs of the first n_programs of a BFS iterator with observational equivalance
    program_iterator = BFSIterator(grammar, output_type, max_size = max_program_size)

    seen_outputs = Set()
    n_programs_iterated = 0

    for program in program_iterator#Iterators.take(program_iterator, n_programs)
        n_programs_iterated += 1
        outputs = []

        for input in inputs
            output = interpreter(program, grammar_tags, input)

            push!(outputs, output)

            if isnothing(output)
                break
            end

        end
        
        if any(isnothing, outputs)
            continue
        end

        if outputs == target_outputs
            throw(ErrorException("Target outputs found in program generation"))

            # println("Target outputs found in program generation")
            # continue 
        end

        push!(seen_outputs, outputs)

        # if length(seen_outputs) >= n_programs
        #     break
        # end
    end

    println("Iterated over $n_programs_iterated programs of max size $max_program_size, creating $(length(seen_outputs)) unique outputs")

    return seen_outputs
end

function create_properties(;
    seen_outputs,
    property_grammar,
    interpreter,
    inputs,
    target_outputs,
    output_type,
    boolean_type,
    max_property_size,
)
    # Add argument rules for the output and constrain grammar to include them
    add_rule!(property_grammar, Expr(:(=), output_type, :_arg_out))
    rule_index = length(property_grammar.rules)
    addconstraint!(property_grammar, Contains(rule_index))
    grammar_tags = get_relevant_tags(property_grammar)

    # Generate properties
    property_iterator = BFSIterator(property_grammar, boolean_type, max_size = max_property_size)
    properties = []
    n_properties_attempted = 0

    # Seen property values
    values_per_property = []

    for property in property_iterator
        # expr = rulenode2expr(property, property_grammar)
        # @show expr

        n_properties_attempted += 1
        
        # Compute values V_t = p(o_t, x_1, x_2) for each concrete I/O example
        [input[:_arg_out] = target_outputs[i] for (i, input) in enumerate(inputs)]

        values_target = []

        for input in inputs
            value_target = interpreter(property, grammar_tags, input)

            push!(values_target, value_target)

            if isnothing(value_target)
                break
            end
        end
        
        # Prune p if it produced an error (nothing)
        if any(isnothing, values_target)
            continue
        end
        
        # Discard p if V contains any false value
        if any(!, values_target)
            continue
        end
    
        # Compute list of values V_i = p(o_i, x_1, x_2) for each concrete I/candidate O example
        property_values = []
        produced_error = false

        for outputs in seen_outputs
            [input[:_arg_out] = outputs[i] for (i, input) in enumerate(inputs)]
            values = [interpreter(property, grammar_tags, input) for input in inputs]

            # Prune if p produced an error (nothing)
            if any(isnothing, values)
                produced_error = true
                break
            end

            push!(property_values, values)
        end

        # Prune if p produced an error (nothing)
        if produced_error
            continue
        end

        # Discard p if V_i is only trues
        if all([all(pv) for pv in property_values])
            continue
        end

        # Discard p if V_i is in V
        if property_values in values_per_property
            continue
        end

        push!(values_per_property, property_values)
        push!(properties, deepcopy(property))
    end

    println("Iterated over $n_properties_attempted properties of max size $max_property_size of which $(length(properties)) are valid")

    return properties, values_per_property
end

function select_properties(;
    properties,
    values_per_property,
    property_grammar,
    ideal_prune_ratio,
    max_number_of_properties,
)

    # Intialize set of selected properties as empty
    selected_properties = []

    # A set which has an entry for each program that contains the list of values produced for each property
    values_per_program = []

    for program_index in 1:length(values_per_property[1])
        program_values = [values_per_property[i][program_index] for i in 1:length(properties)]
        push!(values_per_program, program_values)
    end

    original_values_per_program = deepcopy(values_per_program)

    programs_left = length(values_per_program)

    println("\nStarting property selection")
    @show programs_left
    println()

    # Continue until each other program is falsifies some other property
    while length(values_per_program) > 0
        most_falsefied_property = nothing
        most_falsefied_amount = 0
        lowest_cost = Inf

        # find the property p that yields at least one false for the most programs
        for i in 1:length(properties)
            falsified_amount = count([!all(values[i]) for values in values_per_program])
            cost = abs(length(values_per_program) * ideal_prune_ratio - falsified_amount)

            # if falsified_amount > most_falsefied_amount
            #     most_falsefied_property = i
            #     most_falsefied_amount = falsified_amount
            # end

            if cost < lowest_cost
                most_falsefied_property = i
                most_falsefied_amount = falsified_amount
                lowest_cost = cost
            end
        end

        if isnothing(most_falsefied_property)
            println("Cannot falsify anything anymore")
            break
        end

        # Add property p to P
        push!(selected_properties, properties[most_falsefied_property])

        # Remove the program values from V that produced at least one false on property p
        filter!(v -> all(v[most_falsefied_property]), values_per_program) 

        selected_property = rulenode2expr(properties[most_falsefied_property], property_grammar)
        @show selected_property

        falsified_amount = most_falsefied_amount
        @show falsified_amount

        original_falsified_amount = count([!all(values[most_falsefied_property]) for values in original_values_per_program])
        @show original_falsified_amount

        programs_left = length(values_per_program)
        @show programs_left
        println()

        if length(selected_properties) >= max_number_of_properties
            println("Max amount of selected properties reached")
            break
        end
    end

    return selected_properties
end


function find_programs_satisfying_properties(;
    grammar,
    property_grammar,
    properties,
    interpreter,
    output_type,
    max_program_size,    
)
    grammar_tags = get_relevant_tags(grammar)
    grammar_tags_property = get_relevant_tags(property_grammar)

    # Create the outputs of the first n_programs of a BFS iterator with observational equivalance
    program_iterator = BFSIterator(grammar, output_type, max_size = max_program_size)

    seen_outputs = Set()
    programs = []

    for program in program_iterator
        satisfies = true
        outputs = []

        for input in inputs
            output = interpreter(program, grammar_tags, input)

            if isnothing(output)
                satisfies = false
                break
            end

            input[:_arg_out] = output

            for property in properties
                value = interpreter(property, grammar_tags_property, input)

                if !value
                    satisfies = false
                    break
                end
            end

            push!(outputs, output)

            if !satisfies
                break
            end
        end
        
        if satisfies && !(outputs in seen_outputs)
            push!(programs, deepcopy(program))
            push!(seen_outputs, outputs)
        end
    end

    return programs
end