function create_extensions(grammar, starting_symbol, max_depth)
    extensions = []
    type_to_possible_children = Dict(
        type => collect(BFSIterator(grammar, type, max_depth=max_depth))
        for type in unique(grammar.types)
    )
    
    for (rule_id, type) in enumerate(grammar.types)
        type == starting_symbol || continue

        arity = length(grammar.childtypes[rule_id])
        
        for extendable_index in 1:arity
            possible_children = [
                type_to_possible_children[type]
                for (child_index, type) in enumerate(grammar.childtypes[rule_id])
                if child_index != extendable_index
            ]

            for children_tuple in Iterators.product(possible_children...)
                children = collect(children_tuple)

                extension = rulenode -> RuleNode(rule_id, vcat(
                    children[begin:extendable_index-1],
                    [rulenode],
                    children[extendable_index:end]))

                push!(extensions, extension)
            end
        end
    
    end

    return extensions
end

function create_properties(grammar, starting_symbol, max_depth)
    return collect(BFSIterator(grammar, starting_symbol, max_depth=max_depth))
end

function create_intermediate_outputs(grammar, starting_symbol, max_depth, interpreter)
    return [interpreter(program, []) for program in BFSIterator(grammar, starting_symbol, max_depth=max_depth)]
end

function score_properties(;
    program_grammar,
    program_starting_symbol,
    max_program_depth,
    property_grammar,
    property_starting_symbol,
    max_property_depth,
    max_extension_depth,
)
    property_scores = DefaultDict(0)

    for property in create_properties(property_grammar, property_starting_symbol, max_property_depth)
        for program in BFSIterator(program_grammar, program_starting_symbol, max_depth=max_program_depth)
            program_output = interp(program, Dict())
            property_value_program = interp(property, Dict(:_arg_1 => program_output))

            for extension in create_extensions(program_grammar, program_starting_symbol, max_extension_depth)
                extended_program_output = interp(extension(program), Dict())
                property_value_extended_program = interp(property, Dict(:_arg_1 => extended_program_output))

                if !property_value_program && property_value_extended_program
                    property_scores[property] += 1
                end

                if property_value_program && !property_value_extended_program
                    property_scores[property] -= 1
                end
            end
        end
    end
    
    return property_scores
end

function show_scored_properties(property_scores)
    sorted_property_scores = sort(collect(property_scores), by = last, rev = true)

    for (property, score) in sorted_property_scores
        e = rulenode2expr(property, prop_grammar)
        s = score

        println("")
        @show e
        @show s
    end
end