@testitem "ASP Iterators" begin
    using HerbCore
    using HerbGrammar
    using HerbConstraints
    using HerbSearch: BFSIterator, BFSASPIterator, DFSASPIterator
    using Clingo_jll

    answer_programs = [
        @rulenode(1),
        @rulenode(2),
        @rulenode(3{1,1}),
        @rulenode(3{1,2}),
        @rulenode(3{2,1}),
        @rulenode(3{2,2}),
    ]

    @testset "BFS ASP Iterator" begin
        g1 = @csgrammar begin
            Real = 1 | 2
            Real = Real * Real
        end
        bfs_programs = [freeze_state(p) for p ∈ BFSASPIterator(g1, :Real, max_depth=2)]
        # Test for increasing program depth
        @test all(map(t -> depth(t[1]) ≤ depth(t[2]), zip(bfs_programs[begin:end-1], bfs_programs[begin+1:end])))

        @test length(bfs_programs) == 6
        @test all(p ∈ bfs_programs for p ∈ answer_programs)
    end

    @testset "DFS ASP Iterator" begin
        g1 = @csgrammar begin
            Real = 1 | 2
            Real = Real * Real
        end

        dfs_programs = [freeze_state(p) for p ∈ DFSASPIterator(g1, :Real, max_depth=2)]

        @test length(dfs_programs) == 6
        @test all(p ∈ dfs_programs for p ∈ answer_programs)
    end

    @testset "Forbid(1{a,b})" begin
        g1 = @csgrammar begin
            Real = 1 | 2
            Real = Real * Real
            Real = Var
            Var = x
        end
        f = Forbidden(RuleNode(3, [VarNode(:a), VarNode(:a)]))
        u = Unique(3)
        addconstraint!(g1, f)
        addconstraint!(g1, u)
        bfs_programs = [freeze_state(p) for p ∈ BFSASPIterator(g1, :Real, max_depth=3)]
        @test !((@rulenode 3{1,1}) in bfs_programs)
        @test !((@rulenode 3{2,2}) in bfs_programs)
        @test !((@rulenode 3{5,5}) in bfs_programs)
        @test (@rulenode 3{2,1}) in bfs_programs
        @test (@rulenode 3{1,2}) in bfs_programs
        @test (@rulenode 3{1,4{5}}) in bfs_programs
        @test (@rulenode 3{4{5},1}) in bfs_programs
        @test (@rulenode 3{2,4{5}}) in bfs_programs
        @test (@rulenode 3{4{5},2}) in bfs_programs
        @test length(bfs_programs) == 9
    end

    @testset "Forbid(1{a,a}) with 2-alias grammar" begin
        #         r = Any[0,
        #             1, 2,
        #             :X, :Const, :Entity, :(Expr + Expr),
        # :(Expr - Expr), :(Expr / Expr), :(Expr * Expr), :(min(Expr, Expr)), :(max(Expr, Expr)), :(ceil(Expr)), :(floor(Expr)),
        #
        #         :(Assign(Entity, Expr)), 
        #         # :([Fn])
        # ]
        #         t = Union{Nothing, Symbol}[:Const,
        # :Const, :Const,
        #             :Entity, :Expr, :Expr, :Expr,
        #             :Expr, :Expr, :Expr, :Expr, :Expr, :Expr, :Expr,
        #             :Fn,
        #             # :Model
        # ]
        #         exprs = [:($t = $r) for (t, r) in zip(t, r)]
        #         g = ContextSensitiveGrammar()
        #         HerbGrammar.add_rule!.((g,), exprs)
        # f = Forbidden(HerbConstraints.DomainRuleNode(g, [7, 8, 9, 10, 11, 12], [VarNode(:a), VarNode(:a)]))
        g = @csgrammar begin
            Const = 0
            Entity = X
            Expr = Const | Entity
            Expr = Expr + Expr
        end
        f = Forbidden(HerbConstraints.DomainRuleNode(g, [5], [VarNode(:a), VarNode(:a)]))
        addconstraint!(g, f)
        bfs_programs = rulenode2expr.([freeze_state(p) for p ∈ BFSASPIterator(g, :Expr, max_depth=3)], (g,))
        @test :(X + 0) in bfs_programs
        @test :(0 + X) in bfs_programs
        @test !(:(X + X) in bfs_programs)
        @test !(:(1 + 1) in bfs_programs)
    end

    @testset "Issue 175: Invalid mapping" begin
        g = @csgrammar begin
            Int = Int + Int
            Int = 1 | 2
        end
        iter = BFSASPIterator(g, :Int, max_depth=3)
        @test length(collect(iter)) > 0
    end

    @testset "Alias rules issue" begin
        g = @csgrammar begin
            Expr = Expr + Expr
            Expr = Const | Var
            Const = 0 | 1 | 2
            Var = X
        end

        addconstraint!(g, Forbidden(DomainRuleNode(g, [1], [VarNode(:x), (@rulenode 2{4})])))
        addconstraint!(g, Forbidden(DomainRuleNode(g, [1], [(@rulenode 2{4}), VarNode(:x)])))
        iter = BFSIterator(g, :Expr, max_depth=3)
        iter_asp = BFSASPIterator(g, :Expr, max_depth=3)
        exprs = rulenode2expr.(iter, (g,))
        exprs_asp = rulenode2expr.(iter_asp, (g,))
        @test :(X + 0) ∉ exprs
        @test :(X + 0) ∉ exprs_asp
        @test :(X + 1) ∈ exprs
        @test :(X + 1) ∈ exprs_asp

        @test length(exprs) == length(exprs_asp)
        @test Set(exprs) == Set(exprs_asp)
    end

    @testset "No alias rules (to compare)" begin
        g = @csgrammar begin
            Expr = Expr + Expr
            Expr = 0 | 1 | 2
            Expr = X
        end

        addconstraint!(g, Forbidden(DomainRuleNode(g, [1], [VarNode(:x), RuleNode(2)])))
        addconstraint!(g, Forbidden(DomainRuleNode(g, [1], [RuleNode(2), VarNode(:x)])))
        iter = BFSIterator(g, :Expr, max_depth=3)
        iter_asp = BFSASPIterator(g, :Expr, max_depth=3)
        exprs = rulenode2expr.(iter, (g,))
        exprs_asp = rulenode2expr.(iter_asp, (g,))
        @test :(X + 0) ∉ exprs
        @test :(X + 0) ∉ exprs_asp
        @test :(X + 1) ∈ exprs
        @test :(X + 1) ∈ exprs_asp

        @test length(exprs) == length(exprs_asp)
        @test Set(exprs) == Set(exprs_asp)
    end
end
