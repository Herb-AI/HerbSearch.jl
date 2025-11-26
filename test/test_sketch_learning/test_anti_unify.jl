using HerbGrammar, HerbCore, HerbSpecification

@testset verbose=true "MST Anti-unification methods" begin
    grammar = @csgrammar begin
        Number = 0 | 1 | 2 | 3
        Number = Number + Number
        Number = Number * Number
        Number = x
        end

    @testset verbose=true "Anti-unification for programs that differ in one of the subtrees" begin
        t1= @rulenode 5{6{7,3}, 2}  # :(x * 2 + 1)
        t2 = @rulenode 5{6{7,5{3,2}},2} # :(x * (2 + 1) + 1
        u = anti_unify(t1, t2, grammar)

        # should be :(x * Number) + 1
        node = @rulenode 5{6{7,UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]]},2}
        u_exp = rulenode2expr(u, grammar)
        node_exp = rulenode2expr(node, grammar)
        @test u_exp == node_exp
        
    end

    @testset verbose=true "Anti-unification for Identical trees" begin
        t1 = @rulenode 6{7,3}
        t2 = @rulenode 6{7,3}
        u = anti_unify(t1, t2, grammar)
        node = @rulenode 6{7,3}

        node_exp = rulenode2expr(node, grammar)
        u_exp = rulenode2expr(u, grammar)

        @test u_exp == node_exp
    end

    @testset verbose=true "Anti-unification for generalization" begin
        t1 = @rulenode 6{7,3}
        t2 = @rulenode 1
        u = anti_unify(t1, t2, grammar)
        expected = UniformHole(grammar.domains[:Number])
        expected_exp = rulenode2expr(expected, grammar)
        u_exp = rulenode2expr(u, grammar)
        @test u_exp == expected_exp
    end

    @testset verbose=true "Pairwise Anti-unification for 2 trees - pattern in subtree" begin
        t1 = @rulenode 6{7,3}
        t2 = @rulenode 5{6{7,3}}
        patterns = all_pairwise_anti_unification(t1, t2, grammar, min_nonholes=2)

        @test length(patterns) == 1
        u = patterns[1]
        u_exp = rulenode2expr(u, grammar)

        expected = @rulenode 6{7,3}
        expected_exp = rulenode2expr(expected, grammar)
        
        @test u_exp == expected_exp
    end

    @testset verbose=true "Pairwise Anti-unification for 2 trees - no pattern" begin
        t1 = @rulenode 6{7,3}
        t2 = @rulenode 7
        patterns = all_pairwise_anti_unification(t1, t2, grammar, min_nonholes=2)

        @test length(patterns) == 0
    end

    @testset verbose=true "Anti-unification for 3 trees - no pattern" begin
        pattern1 = @rulenode 6{7,UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]]} # :(x * Number)
        pattern2 = @rulenode 5{3, 6{7,UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]]}} #  :(2 + x * Number)

        patterns = AbstractRuleNode[pattern1, pattern2]
        tree = @rulenode 5{3, 6{4, 3}}

        final_patterns = AbstractRuleNode[]
        patterns = anti_unify_patterns_and_tree(patterns, tree, grammar)

        @test length(patterns) == 2

        got_exprs = [rulenode2expr(p, grammar) for p in patterns]

        final_pattern1 = @rulenode 6{UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]],UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]]} #:(Number * Number)
        final_pattern2 = @rulenode  5{3,6{UniformHole[Bool[1, 1, 1, 1, 1, 1, 1, 1]],UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]]}} # :(2 + Number * Number)

        @test rulenode2expr(final_pattern1, grammar) in got_exprs
        @test rulenode2expr(final_pattern2, grammar) in got_exprs
        
    end

    @testset verbose=true "FULL MST Anti-unification for 3 trees - patterns found" begin
        tree1 = @rulenode 5{3, 6{2, 3}} # :(2 + 1 * 2)
        tree2 = @rulenode 5{3, 6{3, 4}} # :(2 + 2 * 3)
        tree3 = @rulenode 5{3, 6{4, 3}} # :(2 + 3 * 2)

        trees = AbstractRuleNode[tree1, tree2, tree3]
        results = multi_MST_unify(trees, grammar)
        got_exprs = [rulenode2expr(p, grammar) for p in results]

        @test length(results) == 2 

        expected_1 = @rulenode 5{3,6{UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]],UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]]}} # :(2 + Number * Number)
        expected_2 = @rulenode 6{UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]],UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]]} # :(Number * Number)

        @test rulenode2expr(expected_1, grammar) in got_exprs
        @test rulenode2expr(expected_2, grammar) in got_exprs
        
    end

    @testset verbose=true "FULL MST Anti-unification for 3 trees - no patterns found" begin
        tree1 = @rulenode 5{3, 5{2, 3}} # :(2 + 1 + 2)
        tree2 = @rulenode 5{3,4} # :(2 * 3)
        tree3 = @rulenode 2 # :1

        trees = AbstractRuleNode[tree1, tree2, tree3]
        results = multi_MST_unify(trees, grammar)
       
        @test length(results) == 0
        
    end


    



end

