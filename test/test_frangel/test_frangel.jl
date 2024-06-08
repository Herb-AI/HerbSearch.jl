@testset "FrAngel" verbose = true begin
    include("test_frangel_fragment_utils.jl")
    include("test_frangel_utils.jl")
    include("test_frangel_angelic_utils.jl")
    include("test_frangel_generator.jl")
    include("test_long_hash_map.jl")
    include("test_bit_trie.jl")
    
    include("test_frangel_end_to_end.jl")
end