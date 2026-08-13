@testset verbose = true "Program estimator" begin
    arithmetic = @csgrammar begin
        Real = 1 | 2
        Real = Real * Real
        Real = Real + Real
    end

    multityped = @csgrammar begin
        Real = 1 | 2
        Real = Real + Real
        Bool = true
        Bool = Real < Real
        Bool = Bool && Bool
        Real = Bool ? Real : Real
    end

    @testset "matches enumeration on a single grammar" begin
        g = @csgrammar begin
            Real = |(1:9)
        end

        @test count_programs(g, :Real, max_depth=1) == 9
        @test count_programs(g, :Real, max_depth=3) == 9
        @test count_programs(g, :Real, max_size=1) == 9
        @test count_programs(g, :Real, max_size=4) == 9
        @test count_programs_by_size(g, :Real, 3) == [9, 0, 0]
    end

    @testset "matches enumeration on a depth bound" begin
        for grammar ∈ [arithmetic, multityped], symbol ∈ nonterminals(grammar), depth ∈ 1:3
            @test count_programs(grammar, symbol; max_depth=depth) ==
                  length(BFSIterator(grammar, symbol, max_depth=depth, max_size=typemax(Int)))
        end
    end

    @testset "matches enumeration on a size bound" begin
        for grammar ∈ [arithmetic, multityped], symbol ∈ nonterminals(grammar), size ∈ 1:5
            @test count_programs(grammar, symbol; max_size=size) ==
                  length(BFSIterator(grammar, symbol, max_depth=typemax(Int), max_size=size))
        end
    end

    @testset "matches enumeration on a combined bound" begin
        for grammar ∈ [arithmetic, multityped], symbol ∈ nonterminals(grammar),
            depth ∈ 1:3, size ∈ 1:5

            @test count_programs(grammar, symbol; max_depth=depth, max_size=size) ==
                  length(BFSIterator(grammar, symbol, max_depth=depth, max_size=size))
        end
    end

    @testset "counts per size sum up to the total" begin
        by_size = count_programs_by_size(arithmetic, :Real, 7)
        @test by_size == [2, 0, 8, 0, 64, 0, 640]
        @test sum(by_size) == count_programs(arithmetic, :Real, max_size=7)
    end

    @testset "handles unproductive and empty cases" begin
        # Every derivation of `Bool` is infinite, so it holds no programs at all.
        unproductive = @csgrammar begin
            Real = 1
            Bool = Bool && Bool
        end
        @test count_programs(unproductive, :Bool, max_depth=100) == 0
        @test count_programs(unproductive, :Bool, max_size=100) == 0

        @test count_programs(arithmetic, :Real, max_depth=0) == 0
        @test count_programs(arithmetic, :Real, max_size=0) == 0
        @test isempty(count_programs_by_size(arithmetic, :Real, 0))
    end

    @testset "is fast on counts that cannot be enumerated" begin
        # 2^(2^20) programs at depth 21, so this must not enumerate anything.
        @test count_programs(arithmetic, :Real, max_depth=21) > big(2)^(2^20)
        @test count_programs(arithmetic, :Real, max_size=101) > big(10)^50
    end

    @testset "argument validation" begin
        @test_throws ArgumentError count_programs(arithmetic, :Real)
        @test_throws ArgumentError count_programs(arithmetic, :Bool, max_depth=2)
        @test_throws ArgumentError count_programs_by_size(arithmetic, :Bool, 2)
    end

    @testset "ignores constraints" begin
        constrained = @csgrammar begin
            Real = 1 | 2
            Real = Real * Real
        end
        addconstraint!(constrained, Forbidden(RuleNode(3, [RuleNode(1), RuleNode(1)])))

        @test count_programs(constrained, :Real, max_depth=2) == 6
        @test length(BFSIterator(constrained, :Real, max_depth=2)) == 5
    end
end
