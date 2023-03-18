function probabilistic_accept(current_cost, program_to_consider_cost)
    ratio = current_cost / program_to_consider_cost 
    # if the program_to_consider cost is smaller ratio will be above one
    # @info "Ratio is $ratio"
    if ratio >= 1
        # @info "Accepted! Ratio >= 1"
        return true
    end 

    random_number = rand()
    # @debug "Ratio $ratio Random $random_number"

    if ratio >= random_number
        # @info "Accepted!"
        return true
    end

    # @info "Rejected!"
    return false
end

function best_accept(current_cost, program_to_consider_cost)
    return current_cost > program_to_consider_cost
end
