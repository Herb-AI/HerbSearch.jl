using HerbGrammar, HerbCore, HerbSpecification

@testset verbose=true "MST Anti-unification" begin
    grammar = @csgrammar begin
        Number = 0 | 1 | 2 | 3
        Number = Number + Number
        Number = Number * Number
        Number = x
        Number = Number * x
        end

    @testset verbose=true "Differ in one of the subtrees" begin
        t1= @rulenode 5{6{7,3}, 2}  # :(x * 2 + 1)
        t2 = @rulenode 5{6{7,5{3,2}},2} # :(x * (2 + 1) + 1
        u = anti_unify(t1, t2, grammar)

        # should be :(x * Number) + 1
        node = @rulenode 5{6{7,UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]]},2}
        u_exp = rulenode2expr(u, grammar)
        node_exp = rulenode2expr(node, grammar)
        @test u_exp == node_exp
        
    end

    @testset verbose=true "Identical trees" begin
        t1 = @rulenode 6{7,3}
        t2 = @rulenode 6{7,3}
        u = anti_unify(t1, t2, grammar)
        node = @rulenode 6{7,3}

        node_exp = rulenode2expr(node, grammar)
        u_exp = rulenode2expr(u, grammar)

        @test u_exp == node_exp
    end

    @testset verbose=true "Generalization" begin
        t1 = @rulenode 6{7,3}
        t2 = @rulenode 1
        u = anti_unify(t1, t2, grammar)
        expected = UniformHole(grammar.domains[:Number])
        expected_exp = rulenode2expr(expected, grammar)
        u_exp = rulenode2expr(u, grammar)
        @test u_exp == expected_exp
    end


    



end

