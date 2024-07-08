@testset "LongHashMap" begin
    @testset "basic put and contains" begin
        map = init_long_hash_map()

        @test !lhm_contains(map, UInt64(1))

        lhm_put!(map, UInt64(1))

        @test lhm_contains(map, UInt64(1))
        @test !lhm_contains(map, UInt64(2))

        lhm_put!(map, UInt64(1))

        lhm_put!(map, UInt64(2))

        @test lhm_contains(map, UInt64(1))
        @test lhm_contains(map, UInt64(2))
    end
end