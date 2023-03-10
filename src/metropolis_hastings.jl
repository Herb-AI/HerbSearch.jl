using Random

function mh_constructNeighbourhood(current_program::RuleNode, grammar::Grammar)
    # get a random position in the tree (parent,child index)
    node_location::NodeLoc = sample(NodeLoc, current_program)
    return node_location, nothing
end

function mh_temperature(previous_temperature)
    return previous_temperature
end

function mh_propose!(current_program, neighbourhood_node_loc, grammar, max_depth, dict)
    # it can change the current_program for fast replacing of the node
    # find the symbol of subprogram
    subprogram = get(current_program, neighbourhood_node_loc)
    neighbourhood_symbol = return_type(grammar, subprogram)

    # find the depth of subprogram 
    current_depth = node_depth(current_program, subprogram) 
    # this is depth that we can still generate without exceeding max_depth
    remaining_depth = max_depth - current_depth

    if remaining_depth == 0
        # can't expand more => return current program 
        @warn "Can't extend program because we reach max_depth $(rulenode2expr(current_program, grammar))"
        return [current_program]
    end

    @assert remaining_depth >= 1 "remaining_depth $remaining_depth should be bigger than 1 here"
    # generate completely random expression (subprogram) with remaining_depth
    new_random = rand(RuleNode, grammar, neighbourhood_symbol, remaining_depth)
    @assert depth(new_random) <= remaining_depth "The depth of new random = $(depth(new_random)) but remaning depth =  $remaining_depth. 
            Expreesion was $(rulenode2expr(current_program,grammar))"

    # replace node at node_location with new_random 
    if neighbourhood_node_loc.i == 0
        current_program = new_random
        @info "Replacing the root entirely"
    else 
        # update current_program with the subprogram generated
        neighbourhood_node_loc.parent.children[neighbourhood_node_loc.i] = new_random
    end

    @assert depth(current_program) <= max_depth "Depth of program is $(depth(current_program)) but max_depth = $max_depth"
    return [current_program]
end

function mh_accept(current_cost, program_to_consider_cost)
    ratio = current_cost / program_to_consider_cost 
    # if the program_to_consider cost is smaller ratio will be above one
    @info "Ratio is $ratio"
    if ratio >= 1
        @info "Accepted! Ratio >= 1"
        return true
    end 

    random_number = rand()
    @debug "Ratio $ratio Random $random_number"

    if ratio >= random_number
        @info "Accepted!"
        return true
    end

    @info "Rejected!"
    return false
end



function wrong_results(results::AbstractVector{Tuple{Int64, Int64}})
    return count(pair -> pair[1] != pair[2], results) / length(results)
end

function mean_squared_error(results::AbstractVector{Tuple{Int64, Int64}})
    cost = 0
    for (expected, actual) in results
        cost += (expected - actual) ^ 2
    end
    return cost / length(results)
end
