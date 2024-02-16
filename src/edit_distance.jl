function edit_distance(firstString::AbstractString, secondString::AbstractString)
    n = length(firstString)
    m = length(secondString)
    dp = zeros(Int, n + 1, m + 1)

    for i in 1:n
        dp[i + 1, 1] = i
    end

    for j in 1:m
        dp[1, j + 1] = j
    end

    for i in 1:n
        for j in 1:m
            if firstString[i] == secondString[j]
                dp[i + 1, j + 1] = min(dp[i, j], dp[i + 1, j] + 1, dp[i, j + 1] + 1)
            else
                dp[i + 1, j + 1] = min(dp[i, j] + 1, dp[i + 1, j] + 1, dp[i, j + 1] + 1)
            end
        end
    end

    return dp[n + 1, m + 1]
end

# Example usage:
firstString = "5.1"
secondString = "1"
result = edit_distance(firstString, secondString)
println("Edit Distance: ", result)