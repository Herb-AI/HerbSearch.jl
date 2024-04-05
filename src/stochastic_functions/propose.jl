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
function random_fill_propose(solver::Solver, path::Vector{Int}, dict::Union{Nothing,Dict{String,Any}})
    return Iterators.take(RandomSearchIterator(get_grammar(solver), :ThisIsIgnored, solver=solver, path = path),1)
end 

"""
    enumerate_neighbours_propose(enumeration_depth::Int64)

The return function is a function that produces a list with all the subprograms with depth at most `enumeration_depth`.
# Arguments
- `enumeration_depth::Int64`: the maximum enumeration depth.
"""
function enumerate_neighbours_propose(enumeration_depth::Int64)
    return (solver::Solver, path::Vector{Int}, dict::Union{Nothing,Dict{String,Any}}) -> begin
        return BFSIterator(get_grammar(solver), :ThisIsIgnored, solver=solver)  
    end
end
    

