"""
For efficiency reasons, the propose functions return the proposed subprograms.
These subprograms are supposed to replace the subprogram at neighbourhood node location.
It is the responsibility of the caller to make this replacement.
"""



"""
Returns a list with only one proposed, completely random, subprogram.
# Arguments
- `current_program::RuleNode`: the current program.
- `neighbourhood_node_loc::NodeLoc`: the location of the program to replace.
- `grammar::Grammar`: the grammar used to create programs.
- `max_depth::Int`: the maximum depth of the resulting programs.
- `dict::Dict{String, Any}`: the dictionary with additional arguments; not used.
"""
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

"""
Returns a list with all the subprograms constructed by using a subset of the grammar rules with depth at most 2.
The function expects the entry with key "rule_subset" in `dict` and value of type Vector{Any}.
# Arguments
- `current_program::RuleNode`: the current program.
- `neighbourhood_node_loc::NodeLoc`: the location of the program to replace.
- `grammar::Grammar`: the grammar used to create programs.
- `max_depth::Int`: the maximum depth of the resulting programs.
- `dict::Dict{String, Any}`: the dictionary with additional arguments; must contain "rule_subset"
"""
function enumerate_neighbours_propose(current_program, neighbourhood_node_loc, grammar, max_depth, dict)
    # it can change the current_program for fast replacing of the node
    # find the symbol of subprogram
    subprogram = get(current_program, neighbourhood_node_loc)
    neighbourhood_symbol = return_type(grammar, subprogram)

    # find the depth of subprogram
    current_depth = node_depth(current_program, subprogram)
    # this is depth that we can still generate without exceeding max_depth
    remaining_depth = max_depth - current_depth + 1  # TODO: make use of remaining depth

    subset_grammar = ContextFreeGrammar(dict["rule_subset"], grammar.types, grammar.isterminal,
        grammar.iseval, grammar.bytype, grammar.childtypes, grammar.log_probabilities)

    replacement_expressions_enumerator = get_bfs_enumerator(subset_grammar, 2, neighbourhood_symbol)  # TODO: change depth - not hard coded
    replacement_expressions = collect(replacement_expressions_enumerator)
    # @info("$replacement_expressions")

    return replacement_expressions
end
