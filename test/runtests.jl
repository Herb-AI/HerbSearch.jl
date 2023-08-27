using HerbCore
using HerbSearch
using HerbGrammar
using HerbEvaluation
using HerbConstraints
using HerbData
using Test

include("test_helpers.jl")
using Random
Random.seed!(1234)

@testset "HerbSearch.jl" verbose=true begin
    # include("realistic_search_tests.jl")
    include("test_stochastic_functions.jl")
    include("test_stochastic_algorithms.jl")
    include("test_context_sensitive_iterators.jl")
    include("test_search_procedure.jl")        
    include("test_context_free_iterators.jl")
    include("test_sampling.jl")
    include("test_genetic.jl")
end
