@testitem "Stochastic" begin
    using Random
    Random.seed!(1234)
    using HerbCore, HerbGrammar, HerbConstraints, HerbSpecification

    include("../test_helpers.jl")

    include("test_stochastic_functions.jl")
    include("test_stochastic_algorithms.jl")
    include("test_stochastic_with_constraints.jl")
end
