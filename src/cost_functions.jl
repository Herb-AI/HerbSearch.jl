"""
Returns the amount of misclassified examples, i.e. how many tuples with non-matching entries are there in `results`.
# Arguments
- `results::AbstractVector{Tuple{Int64, Int64}}`: the vector of tuples, where each tuple is in the form `Tuple{expected_output, actual_output}`.
"""
function accuracy(results::AbstractVector{Tuple{Int64,Int64}})
    return count(pair -> pair[1] != pair[2], results) / length(results)
end

"""
Returns the mean squared error of `results`.
# Arguments
- `results::AbstractVector{Tuple{Int64, Int64}}`: the vector of tuples, where each tuple is in the form `Tuple{expected_output, actual_output}`.
"""
function mean_squared_error(results::AbstractVector{Tuple{Int64,Int64}})
    cost = 0
    for (expected, actual) in results
        cost += (expected - actual)^2
    end
    return cost / length(results)
end
