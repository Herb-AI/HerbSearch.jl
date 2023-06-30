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

    # generate completely random expression (subprogram) with remaining_depth
    replacement = rand(RuleNode, grammar, neighbourhood_symbol, remaining_depth)

    return [replacement]
end

"""
The return function is a function that produces a list with all the subprograms with depth at most `enumeration_depth`.
# Arguments
- `enumeration_depth::Int64`: the maximum enumeration depth.
"""
function enumerate_neighbours_propose(enumeration_depth::Int64)
    return (current_program, neighbourhood_node_loc, grammar, max_depth, dict) -> begin
        # it can change the current_program for fast replacing of the node
        # find the symbol of subprogram
        subprogram = get(current_program, neighbourhood_node_loc)
        neighbourhood_symbol = return_type(grammar, subprogram)
    
        # find the depth of subprogram
        current_depth = node_depth(current_program, subprogram)
        # this is depth that we can still generate without exceeding max_depth
        remaining_depth = max_depth - current_depth + 1  
        depth_left = min(remaining_depth, enumeration_depth)

        return get_bfs_enumerator(grammar, depth_left, typemax(Int), neighbourhood_symbol)  
    end
end
    

