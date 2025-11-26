using Logging

using HerbGrammar, HerbCore, HerbSpecification

@testset verbose=true "MST Anti-unification utils methods" begin
    grammar = @csgrammar begin
        Number = 0 | 1 | 2 | 3
        Number = Number + Number
        Number = Number * Number
        Number = x
        Number = Number * x
    end

    @testset verbose=true "Collection of subtrees" begin
        tree = @rulenode 5{6{7,3}, 2}  # :(x * 2 + 1)
        subtrees = collect_subtrees(tree)

        @test length(subtrees) == 5
        subtree = subtrees[3]
        expected_subtree = @rulenode 6{7,3}

        exp = rulenode2expr(subtree, grammar)
        expected_exp = rulenode2expr(expected_subtree, grammar)

        @test exp == expected_exp 
    end

    @testset verbose=true "Hole utility functions" begin
        node = @rulenode 5{6{7,UniformHole[Bool[1, 1, 1, 1, 1, 1, 1]]},2}
        holes_num = count_holes(node)
        no_holes_num = count_nonhole_nodes(node)

        @test holes_num == 1
        @test no_holes_num == 4

        
    end

end