import HerbSearch.init_combine_structure

@testset "Bottom Up Search" begin
    @programiterator mutable MyBU(bank) <: BottomUpIterator

    function HerbSearch.init_combine_structure(iter::MyBU)
        Dict(:max => iter.solver.max_depth)
    end

    @testset "basic" begin
        g = @csgrammar begin
            Int = 1 | 2
            Int = Int + Int
        end

        iter = MyBU(g, :Int, nothing; max_depth=5)
        expected_programs = [
            (@rulenode 1),
            (@rulenode 2),
            (@rulenode 3{1,1}),
            (@rulenode 3{2,1}),
            (@rulenode 3{1,2}),
            (@rulenode 3{2,2})
        ]

        progs = [freeze_state(p) for (i, p) in enumerate(iter) if i <= 6]
        @test issetequal(progs, expected_programs)
        @test length(expected_programs) == length(progs)
    end

    @testset "combine" begin
        g = @csgrammar begin
            Int = 1 | 2
            Int = 3 + Int
        end

        iter = MyBU(g, :Int, nothing; max_depth=5)
        create_bank!(iter)
        populate_bank!(iter)

        combinations, state = combine(iter, init_combine_structure(iter))
        @test !isempty(combinations)
    end

    @testset "duplicates not added" begin
        g = @csgrammar begin
            Int = 1 | 2
            Int = 3 + Int
        end

        iter = MyBU(g, :Int, nothing; max_depth=5)

        for p in iter
            @test allunique(Iterators.flatten(values(iter.bank)))
        end
    end

    @testset "Compare to DFS" begin
        @testset "Single-child grammar" begin
            g = @csgrammar begin
                Int = 1 | 2
                Int = 3 + Int
            end
            for depth in 1:10
                iter_bu = MyBU(g, :Int, nothing; max_depth=depth)
                iter_dfs = DFSIterator(g, :Int; max_depth=depth)
    
                bottom_up_programs = [freeze_state(p) for p in iter_bu]
                dfs_programs = [freeze_state(p) for p in iter_dfs]
    
                @testset "depth=$depth" begin
                    @test issetequal(bottom_up_programs, dfs_programs)
                    @test length(bottom_up_programs) == length(dfs_programs)
                end
            end
        end
    
        @testset "Branching grammar" begin
            g = @csgrammar begin
                Int = 1 | 2
                Int = Int + Int
            end
    
            for depth in 1:3
                iter_bu = MyBU(g, :Int, nothing; max_depth=depth)
                iter_dfs = DFSIterator(g, :Int; max_depth=depth)
    
                bottom_up_programs = [freeze_state(p) for p in iter_bu]
                dfs_programs = [freeze_state(p) for p in iter_dfs]
    
                @testset "depth=$depth" begin
                    @test issetequal(bottom_up_programs, dfs_programs)
                    @test length(bottom_up_programs) == length(dfs_programs)
                end
            end
        end
    end
end