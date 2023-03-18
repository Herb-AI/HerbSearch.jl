function accuracy(results::AbstractVector{Tuple{Int64, Int64}})
    return count(pair -> pair[1] != pair[2], results) / length(results)
end

function mean_squared_error(results::AbstractVector{Tuple{Int64, Int64}})
    cost = 0
    for (expected, actual) in results
        cost += (expected - actual) ^ 2
    end
    return cost / length(results)
end
