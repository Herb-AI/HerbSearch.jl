"""
For efficiency reasons, the propose functions return the proposed subprograms.
These subprograms are supposed to replace the subprogram at neighbourhood node location.
It is the responsibility of the caller to make this replacement.
"""


"""
    random_fill_propose(current_program::RuleNode, neighbourhood_node_loc::NodeLoc, grammar::AbstractGrammar, max_depth::Int, dmap::AbstractVector{Int}, dict::Union{Nothing,Dict{String,Any}})

Returns a list with only one proposed, completely random, subprogram.
# Arguments
- `current_program::RuleNode`: the current program.
- `neighbourhood_node_loc::NodeLoc`: the location of the program to replace.
- `grammar::AbstractGrammar`: the grammar used to create programs.
- `max_depth::Int`: the maximum depth of the resulting programs.
- `dmap::AbstractVector{Int} : the minimum possible depth to reach for each rule`
- `dict::Dict{String, Any}`: the dictionary with additional arguments; not used.
"""
function random_fill_propose(current_program::RuleNode, neighbourhood_node_loc::NodeLoc, solver::Solver, dmap::AbstractVector{Int}, dict::Union{Nothing,Dict{String,Any}})
    # it can change the current_program for fast replacing of the node
    # find the symbol of subprogram
    subprogram = get(current_program, neighbourhood_node_loc)
    neighbourhood_symbol = return_type(get_grammar(solver), subprogram)

    # find the depth of subprogram 
    current_depth = node_depth(current_program, subprogram)
    # this is depth that we can still generate without exceeding max_depth
    remaining_depth = get_max_depth(solver) - current_depth + 1

    if remaining_depth == 0
        # can't expand more => return current program 
        @warn "Can't extend program because we reach max_depth $(rulenode2expr(current_program, get_grammar(solver)))"
        return [current_program]
    end

    # generate completely random expression (subprogram) with remaining_depth
    replacement = rand(RuleNode, get_grammar(solver), neighbourhood_symbol, dmap, remaining_depth)

    return [replacement]
end

"""
    enumerate_neighbours_propose(enumeration_depth::Int64)

The return function is a function that produces a list with all the subprograms with depth at most `enumeration_depth`.
# Arguments
- `enumeration_depth::Int64`: the maximum enumeration depth.
"""
function enumerate_neighbours_propose(enumeration_depth::Int64)
    return (current_program::RuleNode, neighbourhood_node_loc::NodeLoc, grammar::AbstractGrammar, max_depth::Int, dmap::AbstractVector{Int}, dict::Union{Nothing,Dict{String,Any}}) -> begin
        # it can change the current_program for fast replacing of the node
        # find the symbol of subprogram
        subprogram = get(current_program, neighbourhood_node_loc)
        neighbourhood_symbol = return_type(grammar, subprogram)
    
        # find the depth of subprogram
        current_depth = node_depth(current_program, subprogram)
        # this is depth that we can still generate without exceeding max_depth
        remaining_depth = max_depth - current_depth + 1  
        depth_left = min(remaining_depth, enumeration_depth)

        return BFSIterator(grammar, neighbourhood_symbol, max_depth=depth_left)  
    end
end
    

