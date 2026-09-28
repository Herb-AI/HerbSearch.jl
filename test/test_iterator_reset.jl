using Test
using HerbCore, HerbGrammar, HerbSearch

@testset "Iterator restart behaviour" begin
    # regression test for https://github.com/HerbSearch/HerbSearch.jl/issues/175
    @testset "solver state reset between iterations" begin
        g = @csgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end
        iter = BFSIterator(g, :Number, max_depth=3)

        l1 = length(iter)
        l2 = length(iter)
        l3 = length(iter)
        @test l1 == l2
        @test l1 == 885
        @test l3 == 885
        @test length(collect(iter)) == l1

        iter2 = BFSIterator(g, :Number, max_depth=3)
        @test length(collect(iter2)) == l1
    end

    @testset "solver state reset between iterations and multi grammar" begin
        g = @csgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end
        iter = BFSIterator(g, :Number, max_depth=3)

        l1 = length(iter)
        l2 = length(iter)
        l3 = length(iter)
        @test l1 == l2
        @test l1 == 885
        @test l3 == 885
        @test length(collect(iter)) == l1

        g2 = @csgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end
        iter2 = BFSIterator(g2, :Number, max_depth=4)
        @test length(collect(iter2)) != l1
    end
end
