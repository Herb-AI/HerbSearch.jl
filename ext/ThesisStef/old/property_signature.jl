struct PropertySigner
    unary_properties::Dict{AbstractRuleNode, Function}
    binary_properties::Dict{AbstractRuleNode, Function}
end

function Base.length(signer::PropertySigner)
    return length(signer.unary_properties) + length(signer.binary_properties)
end

struct PropertySignature
    unary_input_values::Dict{AbstractRuleNode, Vector{Bool}}
    unary_output_values::Dict{AbstractRuleNode, Vector{Bool}}
    binary_values::Dict{AbstractRuleNode, Vector{Bool}}
end

function create_property_signatures(signer::PropertySigner, states::Vector, target::Vector)
    # For each property:
    #   1. Evaluate property to produce values for each state
    #   2. Validity:        Prune if a property creates an argument or bounds error
    #   3. Informativity:   Prune if the values are the for each state
    #   4. Uniqueness:      Prune if another property produce the same values for each state

    # Helper function that evaluates a single property on all inputs and outputs
    # Returns nothing if the property produces an argument or bounds error
    function evaluate_property_on_states(property)
        valuess = []

        for state in states
            values = []

            for (input, output) in zip(state, target)
                value = property(input, output)

                if isnothing(value)
                    return nothing
                end

                push!(values, value)
            end

            push!(valuess, values)
        end

        return valuess
    end

    property_signatures = [PropertySignature(Dict(), Dict(), Dict()) for _ in states]
    seen_valuess = Set()


    for (name, property) in signer.unary_properties
        valuess = evaluate_property_on_states((i, o) -> property(i))

        # 1. Validity: prune if this property produces an argument or bounds error
        if isnothing(valuess)
            delete!(signer.unary_properties, name)
            continue
        end

        # 2. Informativity: prune if this property produces the same values for each state
        if all(==(valuess[1]), valuess)
            delete!(signer.unary_properties, name)
            continue
        end

        # 3. Uniqueness: prune if another property produces the same values for each state
        if valuess in seen_valuess
            delete!(signer.unary_properties, name)
            continue
        end

        push!(seen_valuess, valuess)

        output_valuess = evaluate_property_on_states((i, o) -> property(o))

        for (property_signature, values, output_values) in zip(property_signatures, valuess, output_valuess)
            property_signature.unary_input_values[name] = values
            property_signature.unary_output_values[name] = output_values
        end
    end

    for (name, property) in signer.binary_properties
        valuess = evaluate_property_on_states(property)

        # 1. Validity: prune if this property produces an argument or bounds error
        if isnothing(valuess)
            delete!(signer.binary_properties, name)
            continue
        end

        # 2. Informativity: prune if this property produces the same values for each state
        if all(==(valuess[1]), valuess)
            delete!(signer.binary_properties, name)
            continue
        end

        # 3. Uniqueness: prune if another property produces the same values for each state
        if valuess in seen_valuess
            delete!(signer.binary_properties, name)
            continue
        end

        push!(seen_valuess, valuess)

        for (property_signature, values) in zip(property_signatures, valuess)
            property_signature.binary_values[name] = values
        end
    end


    return property_signatures
end