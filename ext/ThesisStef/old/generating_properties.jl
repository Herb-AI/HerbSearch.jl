
function generate_properties(;
    grammar,
    grammar_extension,
    input_symbol,
    output_symbol,
    amount_of_properties,
    arity,
)   
    # Copy grammar before alterations
    grammar = deepcopy(grammar)
    merge_grammars!(grammar, grammar_extension)

    # Remove all rules with arguments as they will be supplied in a different way
    for (i, r) in enumerate(grammar.rules)
        if startswith("$r", "_arg_")
            remove_rule!(grammar, i)
        end
    end

    cleanup_removed_rules!(grammar)

    # Add argument rules for the inputs and constrain grammar to include them
    for i in 1:arity
        add_rule!(grammar, Expr(:(=), input_symbol, Symbol("_arg_$i")))
        rule_index = length(grammar.rules)
        addconstraint!(grammar, Contains(rule_index))
    end

    # Generate properties
    iterator = BFSIterator(grammar, output_symbol)
    properties = []

    for property in Iterators.take(iterator, amount_of_properties)
        push!(properties, deepcopy(property))
    end

    return properties, grammar
end

function generate_property_signature(;
    grammar,
    grammar_extension,
    input_symbol,
    output_symbol,
    amount_of_unary_properties,
    amount_of_binary_properties,
    interpreter,
)
    (unary_properties, unary_grammar) = generate_properties(
        grammar = grammar,
        grammar_extension = grammar_extension,
        input_symbol = input_symbol,
        output_symbol = output_symbol,
        arity = 1,
        amount_of_properties = amount_of_unary_properties,
    )

    (binary_properties, binary_grammar) = generate_properties(
        grammar = grammar,
        grammar_extension = grammar_extension,
        input_symbol = input_symbol,
        output_symbol = output_symbol,
        arity = 2,
        amount_of_properties = amount_of_binary_properties,
    )

    return PropertySigner(
        Dict(p => input -> interpreter(p, unary_grammar, [input]) for p in unary_properties),
        Dict(p => (input, output) -> interpreter(p, binary_grammar, [input, output]) for p in binary_properties)
    ), (unary_grammar, binary_grammar)
end