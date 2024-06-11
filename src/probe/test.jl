using Statistics

mutable struct ProgramCacheTrace
    program::String
    reward::Int
end

# PSols_with_eval_cache = []

# for i in [1,2,3,4,5,6,7,8]
#     push!(PSols_with_eval_cache, ProgramCacheTrace("$(i)", i*2))
# end
# meanval = mean(p.reward for p in PSols_with_eval_cache)
# println(PSols_with_eval_cache)
# println(meanval)
# println(sum(i*2 for i in [1,2,3,4,5,6,7,8])/8)
# println(1 - exp((-1/meanval) * 9))

best_reward = 20
appearances = 1
fitness = (best_reward / 100) * (log( 1 + appearances))
fitness2 = (best_reward / 100)

println("reward = $(best_reward) and app = $(appearances)")
println(fitness)
println(fitness2)
# println(PSols_with_eval_cache[1:1])
# function flatten_nested_vector(v, result=[])
#     for element in v
#         if isa(element, AbstractVector)
#             flatten_nested_vector(element, result)
#         else
#             push!(result, element)
#         end
#     end
#     return result
# end

# nested_vector = [[[[[ProgramCacheTrace("guy", 5)], ProgramCacheTrace("funny", 4)], ProgramCacheTrace("the", 3)], ProgramCacheTrace("im", 2)], ProgramCacheTrace("hi", 1)]
# flattened = flatten_nested_vector(nested_vector)
# println(flattened)  # Output: ["a", "b", "c", "d", "e"]