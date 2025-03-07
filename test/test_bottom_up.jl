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

    @testset "compare to DFS" begin
        g = @csgrammar begin
            Int = 1 | 2
            Int = 3 + Int
        end

        for depth in 5:10
            iter_bu = MyBU(g, :Int, nothing, depth)
            iter_dfs = DFSIterator(g, :Int; max_depth=depth)

            bottom_up_programs = collect(iter_bu)
            dfs_programs = [freeze_state(p) for p in iter_dfs]

            @test issetequal(bottom_up_programs, dfs_programs)
            @test length(bottom_up_programs) == length(dfs_programs)
        end
    end
end