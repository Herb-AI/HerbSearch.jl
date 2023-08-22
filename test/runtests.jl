using HerbSearch
using Test

@testset "HerbSearch.jl" verbose=true begin
    # include("realistic_search_tests.jl")
    include("test_stochastic_algorithms.jl")
    include("test_context_sensitive_iterators.jl")
    include("test_search_procedure.jl")        
    include("test_context_free_iterators.jl")
    include("test_genetic.jl")
end
