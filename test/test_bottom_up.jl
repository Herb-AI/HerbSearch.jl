import HerbSearch.init_combine_structure

@testset "Bottom Up Search" begin
    grammars_to_test = Dict(
        "arity <= 1" => (@csgrammar begin
            Int = 1 | 2
            Int = 3 + Int
        end),
        "arity = 2" => (@csgrammar begin
            Int = 1 | 2
            Int = Int + Int
        end)
    )

    function test_with_grammars(f, grammars)
        for (name, g) in grammars
            @testset "$name" f(g)
        end
    end

    @programiterator mutable MyBU(bank) <: BottomUpIterator

    function HerbSearch.init_combine_structure(iter::MyBU)
        Dict(:max_combination_depth => 10)
    end

    @testset "basic" begin
        g = grammars_to_test["arity = 2"]
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
        test_with_grammars(grammars_to_test) do g
            iter = MyBU(g, :Int, nothing; max_depth=5)
            create_bank!(iter)
            populate_bank!(iter)

            combinations, state = combine(iter, init_combine_structure(iter))
            @test !isempty(combinations)
        end
    end

    @testset "duplicates not added" begin
        test_with_grammars(grammars_to_test) do g
            iter = MyBU(g, :Int, nothing; max_depth=3)

            for p in iter
                @test allunique(Iterators.flatten(values(iter.bank)))
            end
        end
    end

    @testset "Compare to DFS" begin
        test_with_grammars(grammars_to_test) do g
            for depth in 1:3
                iter_bu = MyBU(g, :Int, nothing; max_depth=depth)
                iter_dfs = DFSIterator(g, :Int; max_depth=depth)
    
                bottom_up_programs = [freeze_state(p) for p in iter_bu]
                dfs_programs = [freeze_state(p) for p in iter_dfs]
    
                @testset "max_depth=$depth" begin
                    @test issetequal(bottom_up_programs, dfs_programs)
                    @test length(bottom_up_programs) == length(dfs_programs)
                end
            end
        end
    end
end