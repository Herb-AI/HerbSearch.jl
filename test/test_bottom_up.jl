import HerbSearch.init_combine_structure

@testset "Bottom Up Search" begin
    mutable struct MyBU <: BottomUpIterator
        grammar
        starts
        bank
        max_depth
    end

    function HerbSearch.init_combine_structure(iter::MyBU)
        Dict(:max => iter.max_depth)
    end

    @testset "basic" begin
        g = @csgrammar begin
            Int = 1 | 2
            Int = Int + Int
        end

        iter = MyBU(g, :Int, nothing, 5)
        expected_programs = Set([
            (@rulenode 1),
            (@rulenode 2),
            (@rulenode 3{1,1}),
            (@rulenode 3{2,1}),
            (@rulenode 3{1,2}),
            (@rulenode 3{2,2})
        ])

        progs = Set(Iterators.take(iter, 6))
        @test progs == expected_programs
    end

    @testset "test combine" begin
        g = @csgrammar begin
            Int = 1 | 2
            Int = 3 + Int
        end

        iter = MyBU(g, :Int, nothing, 5)
        create_bank!(iter)
        populate_bank!(iter)

        combinations, state = combine(iter, init_combine_structure(iter))
        @test !isempty(combinations)
    end
end