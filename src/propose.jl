function random_fill_propose(current_program, neighbourhood_node_loc, grammar, max_depth, dict)
    # it can change the current_program for fast replacing of the node
    # find the symbol of subprogram
    subprogram = get(current_program, neighbourhood_node_loc)
    neighbourhood_symbol = return_type(grammar, subprogram)

    # find the depth of subprogram 
    current_depth = node_depth(current_program, subprogram) 
    # this is depth that we can still generate without exceeding max_depth
    remaining_depth = max_depth - current_depth + 1

    if remaining_depth == 0
        # can't expand more => return current program 
        @warn "Can't extend program because we reach max_depth $(rulenode2expr(current_program, grammar))"
        return [current_program]
    end

    @assert remaining_depth >= 1 "remaining_depth $remaining_depth should be bigger than 1 here"
    # generate completely random expression (subprogram) with remaining_depth
    replacement = rand(RuleNode, grammar, neighbourhood_symbol, remaining_depth)
    @assert depth(replacement) <= remaining_depth "The depth of new random = $(depth(replacement)) but remaning depth =  $remaining_depth. 
            Expreesion was $(rulenode2expr(current_program,grammar))"

    @assert depth(current_program) <= max_depth "Depth of program is $(depth(current_program)) but max_depth = $max_depth"
    return [replacement]
end

function enumerate_neighbours_propose(current_program, neighbourhood_node_loc, grammar, max_depth, dict)
    # it can change the current_program for fast replacing of the node
    # find the symbol of subprogram
    subprogram = get(current_program, neighbourhood_node_loc)
    neighbourhood_symbol = return_type(grammar, subprogram)

    # find the depth of subprogram 
    current_depth = node_depth(current_program, subprogram) 
    # this is depth that we can still generate without exceeding max_depth
    remaining_depth = max_depth - current_depth + 1

    subset_grammar = ContextFreeGrammar(dict["rule_subset"], grammar.types, grammar.isterminal, 
        grammar.iseval, grammar.bytype, grammar.childtypes, grammar.log_probabilities)

    replacement_expressions_enumerator = get_bfs_enumerator(subset_grammar, 2, neighbourhood_symbol)  # TODO: change depth - not hard coded
    replacement_expressions = collect(replacement_expressions_enumerator)
    # @info("$replacement_expressions")

    return replacement_expressions
end