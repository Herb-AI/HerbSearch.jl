"""
    misclassification(results::AbstractVector{Tuple{<:Number,<:Number}})

Returns the amount of misclassified examples, i.e. how many tuples with non-matching entries are there in `results`.
# Arguments
- `results<:AbstractVector{<:Tuple{Number,Number}}`: the vector of tuples, where each tuple is in the form `Tuple{expected_output, actual_output}`.
"""
function misclassification(results::T) where {T<:AbstractVector{<:Tuple{Number,Number}}}
    return count(pair -> pair[1] != pair[2], results) / length(results)
end

"""
    mean_squared_error(results::AbstractVector{Tuple{<:Number,<:Number}})

Returns the mean squared error of `results`.
# Arguments
- `results<:AbstractVector{<:Tuple{Number,Number}}`: the vector of tuples, where each tuple is in the form `Tuple{expected_output, actual_output}`.
"""
function mean_squared_error(results::AbstractVector{<:Tuple{Number,Number}})
    cost = 0
    for (expected, actual) in results
        cost += (expected - actual)^2  / length(results)
        if cost < 0
            return Inf
        end
    end
    return cost
end


function mean_squared_error_strings(results)
    cost = 0
    for (expected, actual) in results
        cost += HerbSearch.mse_error_function_individual_strings(expected, actual)
    end
    return cost / length(results)
end

mse_error_function_individual_strings(output::Char, expected_output::String) = mse_error_function_individual_strings(string(output), expected_output)
mse_error_function_individual_strings(output::String, expected_output::Char) = mse_error_function_individual_strings(output, string(expected_output))
mse_error_function_individual_strings(output::Char, expected_output::Char) = mse_error_function_individual_strings(string(output), string(expected_output))

function mse_error_function_individual_strings(output::String, expected_output::String)
    return edit_distance(output,expected_output)
end