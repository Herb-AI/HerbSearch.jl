@testset "FrAngel" verbose=true begin
    include("test_frangel_fragment_utils.jl")
    include("test_frangel_utils.jl")
    include("test_frangel_iterator.jl")
    include("test_frangel_angelic_utils.jl")
end
