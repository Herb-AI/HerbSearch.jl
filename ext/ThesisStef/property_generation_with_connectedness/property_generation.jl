
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
)
    seen_outputs, program_to_outputs, program_to_parents = generate_programs(
        grammar = grammar,
        interpreter = interpreter,
        inputs = inputs,
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
    
    return nothing
end

function generate_programs(;
    grammar,
    interpreter,
    inputs,
    target_outputs,
    output_type,
    max_program_size,    
)
    grammar_tags = get_relevant_tags(grammar)
    
    program_iterator = SizeBasedBottomUpIterator(grammar, output_type, max_size = max_program_size)

    program_to_outputs = Dict()
    program_to_parents = Dict()
    seen_outputs = Set()

    for program in program_iterator
        outputs = []
        expr = rulenode2expr(program, grammar)
        @show expr

        # for input in inputs
        #     output = interpreter(program, grammar_tags, input)
        #     push!(outputs, output)

        #     if isnothing(output)
        #         break
        #     end
        # end

        # if any(isnothing(outputs))
        #     continue
        # end

        # if outputs == target_outputs
        #     throw(ErrorException("Solution found during exploration"))
        # end

        # if outputs in seen_outputs
        #     continue
        # end

        # program_to_outputs["$program"] = outputs
        # push!(seen_outputs, outputs)

        # program_to_parents["$program"] = []

        # for child in get_children(program)
        #    if haskey(program_to_outputs, "$child")
        #         push!(program_to_parents["$program"], "$child")
        #    end
        # end
    end

    return seen_outputs, program_to_outputs, program_to_parents
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