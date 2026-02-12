
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
    program_to_outputs, program_to_parents = generate_programs(
        grammar = grammar,
        interpreter = interpreter,
        inputs = inputs,
        target_outputs = target_outputs,
        output_type = output_type,
        max_program_size = max_program_size,
    )

    properties, program_to_property_to_values = create_properties(
        program_to_outputs = program_to_outputs,
        property_grammar = property_grammar,
        interpreter = interpreter,
        inputs = inputs,
        target_outputs = target_outputs,
        output_type = output_type,
        boolean_type = boolean_type,
        max_property_size = max_property_size,
    )

    for property in properties
        score_property(
            property = property,
            property_grammar = property_grammar,
            program_to_parents = program_to_parents,
            program_to_property_to_values = program_to_property_to_values,
        )
    end

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
    
    # program_iterator = SizeBasedBottomUpIterator(grammar, output_type, max_size = max_program_size)
    program_iterator = BFSIterator(grammar, output_type, max_size = max_program_size)

    program_to_outputs = Dict()
    program_to_parents = Dict()
    seen_outputs = Set()
    n_programs_iterated = 0

    for program in program_iterator
        n_programs_iterated += 1
        outputs = []

        for input in inputs
            output = nothing 

            try
                output = interpreter(program, grammar_tags, input)
            catch e
                if e isa MethodError
                    output = nothing
                else
                    rethrow(e)
                end
            end

            push!(outputs, output)

            if isnothing(output) || output isa Bool
                break
            end
        end

        if any(isnothing, outputs) || any(v -> (v isa Bool), outputs)
            continue
        end

        if outputs == target_outputs
            throw(ErrorException("Solution found during exploration"))
        end

        if outputs in seen_outputs
            continue
        end

        expr = rulenode2expr(program, grammar)
        program_to_outputs["$expr"] = outputs
        push!(seen_outputs, outputs)

        program_to_parents["$expr"] = []

        for child in get_children(program)
            child_expr = rulenode2expr(child, grammar)
            if haskey(program_to_outputs, "$child_expr")
                    push!(program_to_parents["$expr"], "$child_expr")
            end
        end
    end

    println("Iterated over $n_programs_iterated programs of max size $max_program_size, creating $(length(seen_outputs)) unique outputs")

    return program_to_outputs, program_to_parents
end

function create_properties(;
    program_to_outputs,
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
    values_per_property = Set()
    program_to_property_to_values = Dict(program => Dict() for (program, _) in program_to_outputs)
    property_to_target_value = Dict()

    for property in property_iterator
        # expr = rulenode2expr(property, property_grammar)
        # @show expr

        n_properties_attempted += 1
        
        # Compute values V_t = pi(o_t, x_1, x_2) for each concrete I/O example
        [input[:_arg_out] = target_outputs[i] for (i, input) in enumerate(inputs)]

        values_target = []

        for input in inputs
            value_target = interpreter(property, grammar_tags, input)

            push!(values_target, value_target)

            if isnothing(value_target)
                break
            end
        end

        property_to_target_value["$property"] = values_target
        
        # Prune pi if it produced an error (nothing)
        if any(isnothing, values_target)
            # println("Pruned: invalid")
            continue
        end
        
        # Discard pi if V contains any false value
        if any(!, values_target)
            # println("Pruned: does not hold for solution")
            continue
        end
    
        # Compute list of values V_i = p(o_i, x_1, x_2) for each concrete I/candidate O example
        program_to_values = Dict()
        property_values = []
        produced_error = false

        for (program, outputs) in program_to_outputs
            [input[:_arg_out] = outputs[i] for (i, input) in enumerate(inputs)]
            values = [interpreter(property, grammar_tags, input) for input in inputs]

            expr = rulenode2expr(property, property_grammar)
            if startswith("$expr","prefixof_cvc(at_cvc(_arg_1, 2), _arg_out)")
                if startswith(program, "substr_cvc")
                    @show program
                    @show values
                end
            end

            # Prune if p produced an error (nothing)
            if any(isnothing, values)
                produced_error = true
                break
            end

            push!(property_values, values)
            program_to_values[program] = values
        end

        # Prune if p produced an error (nothing)
        if produced_error
            # println("Pruned: invalid")
            continue
        end

        # Discard p if V_i is only trues
        if all([all(pv) for pv in property_values])
            # println("Pruned: tautology")
            continue
        end

        # Discard p if V_i is in V
        if property_values in values_per_property
            # println("Pruned: redundant")
            continue
        end

        for (program, values) in program_to_values
            program_to_property_to_values[program]["$property"] = values
        end

        push!(values_per_property, property_values)
        push!(properties, deepcopy(property))
    end

    println("Iterated over $n_properties_attempted properties of max size $max_property_size of which $(length(properties)) are valid")

    return properties, program_to_property_to_values
end

function score_property(;
    property,
    property_grammar,
    program_to_parents,
    program_to_property_to_values,
)
    n_falsified_by_programs = 0

    for (program, property_to_value) in program_to_property_to_values
        if !all(property_to_value["$property"])
            n_falsified_by_programs += 1
        end 
    end

    n_disconnected_regions = 0
    roots = []

    for (program, property_to_value) in program_to_property_to_values
        program_satisfies = all(property_to_value["$property"])
        parents_statisfy = [all(program_to_property_to_values[parent]["$property"]) for parent in program_to_parents[program]]
        disconnected = program_satisfies && all(!, parents_statisfy)

        if disconnected
            n_disconnected_regions += 1
            push!(roots, program)
        end
    end

    expr = rulenode2expr(property, property_grammar)
    if startswith("$expr", "!(contains_cvc(_arg_out, ")
        println()
        expr = rulenode2expr(property, property_grammar)
        program_space_size = length(program_to_property_to_values)
        property_space_size = program_space_size - n_falsified_by_programs
        property_space_ratio = property_space_size / program_space_size
        property_space_regions = n_disconnected_regions
        property_space_average_region_size = property_space_size / n_disconnected_regions
        
        @show expr
        @show property_space_size
        @show program_space_size
        @show property_space_ratio
        @show property_space_regions
        @show property_space_average_region_size
        @show roots
    end
end