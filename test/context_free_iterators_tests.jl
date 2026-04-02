@testitem "Context-free iterators" begin
    using HerbGrammar, HerbConstraints, HerbCore
    using HerbSearch: BFSASPIterator, DFSASPIterator
    using Clingo_jll

    const TOPDOWNITERATORS = [BFSIterator, DFSIterator, BFSASPIterator, DFSASPIterator]

    @testset "getters for $it" for it in TOPDOWNITERATORS
        g1 = @csgrammar begin
            Real = |(1:9)
        end

        bfs = it(g1, :Real, max_depth=1, max_size=1)
        @test get_grammar(bfs) == g1
        @test get_solver(bfs) isa HerbConstraints.Solver
        @test get_max_depth(bfs) == 1
        @test get_max_size(bfs) == 1
        @test get_starting_symbol(bfs) == :Real
    end
    @testset "length on single Real grammar: $it" for it in TOPDOWNITERATORS
        g1 = @csgrammar begin
            Real = |(1:9)
        end

        @test length(it(g1, :Real, max_depth=1)) == 9

        # Tree depth is equal to 1, so the max depth of 3 does not change the expression count
        @test length(it(g1, :Real, max_depth=3)) == 9
    end

    @testset "length on grammar with multiplication" for it in TOPDOWNITERATORS
        g1 = @csgrammar begin
            Real = 1 | 2
            Real = Real * Real
        end
        # Expressions: [1, 2]  
        @test length(it(g1, :Real, max_depth=1)) == 2

        # Expressions: [1, 2, 1 * 1, 1 * 2, 2 * 1, 2 * 2] 
        @test length(it(g1, :Real, max_depth=2)) == 6
    end

    grammars = [
        (@csgrammar begin
            Real = 1
            Real = Real * Real
        end),
        (@csgrammar begin
            Real = 1
            Real = Real / Real
        end),
        (@csgrammar begin
            Real = 1
            Real = Real + Real
        end),
        (@csgrammar begin
            Real = 1
            Real = Real - Real
        end),
        (@csgrammar begin
            Real = 1
            Real = Real % Real
        end),
        (@csgrammar begin
            Real = 1
            Real = Real \ Real
        end),
        (@csgrammar begin
            Real = 1
            Real = Real^Real
        end),
        (@csgrammar begin
            Real = 1
            Real = -Real * Real
        end)
    ]

    @testset "length on different arithmetic operators: $it" for it in TOPDOWNITERATORS, g in grammars
        # E.g for multiplication: [1, 1 * 1, 1 * (1 * 1), (1 * 1) * 1, (1 * 1) * (1 * 1)] 
        @testset let g = g
            @test length(it(g, :Real, max_depth=3)) == 5
        end
    end

    @testset "length on grammar with functions: $it" for it in TOPDOWNITERATORS
        g1 = @csgrammar begin
            Real = 1 | 2
            Real = f(Real)                # function call
        end

        # Expressions: [1, 2, f(1), f(2)]
        @test length(it(g1, :Real, max_depth=2)) == 4

        # Expressions: [1, 2, f(1), f(2), f(f(1)), f(f(2))]
        @test length(it(g1, :Real, max_depth=3)) == 6
    end

    answer_programs = [
        RuleNode(1),
        RuleNode(2),
        RuleNode(3, [RuleNode(1), RuleNode(1)]),
        RuleNode(3, [RuleNode(1), RuleNode(2)]),
        RuleNode(3, [RuleNode(2), RuleNode(1)]),
        RuleNode(3, [RuleNode(2), RuleNode(2)])
    ]

    @testset "BFS increasing depth test: $it" for it in [BFSIterator, BFSASPIterator]
        g1 = @csgrammar begin
            Real = 1 | 2
            Real = Real * Real
        end
        bfs_programs = [freeze_state(p) for p ∈ it(g1, :Real, max_depth=2)]
        # Test for increasing program depth
        @test all(map(t -> depth(t[1]) ≤ depth(t[2]), zip(bfs_programs[begin:end-1], bfs_programs[begin+1:end])))

        @test length(bfs_programs) == 6
        @test all(p ∈ bfs_programs for p ∈ answer_programs)
    end

    @testset "BFS matching order, g$i, d=$d" for (i, g) in enumerate(grammars), d in 1:4
        normal_it = BFSIterator(g, :Real; max_depth=d)
        normal_programs = [freeze_state(p) for p in normal_it]
        asp_it = BFSASPIterator(g, :Real; max_depth=d)
        asp_programs = [freeze_state(p) for p in normal_it]
        @testset let g = g, normal_programs = normal_programs, asp_programs = asp_programs
            @test all(herb == asp for (herb, asp) in zip(normal_programs, asp_programs))
        end
    end

    @testset "DFS test: $it" for it in [DFSIterator, DFSASPIterator]
        g1 = @csgrammar begin
            Real = 1 | 2
            Real = Real * Real
        end

        dfs_programs = [freeze_state(p) for p ∈ it(g1, :Real, max_depth=2)]

        @testset let grammar = g1, expected = answer_programs, actual = dfs_programs
            @test length(actual) == 6
            @test all(p ∈ actual for p ∈ expected)
        end
    end

    @testset "MLFSIterator tests" begin
        g = @pcsgrammar begin
            0.2:Real = 1
            0.3:Real = 2
            0.5:Real = Real * Real
        end

        log_p(p) = rulenode_log_probability(p, g)

        iter = MLFSIterator(g, :Real, max_depth=2)

        mlfs_programs = [freeze_state(p) for p ∈ iter]

        # Test for drecreasing program probability
        @test all(map(t -> log_p(t[1]) >= log_p(t[2]), zip(mlfs_programs[begin:end-1], mlfs_programs[begin+1:end])))
        @test length(mlfs_programs) == 6
        @test all(p ∈ mlfs_programs for p ∈ answer_programs)
    end
end
