using Test, HerbCore, HerbGrammar, HerbConstraints
#Cannot use "using HerbSearch" because HerbSearch does not expose this functionality. 
include("../../src/grammar_optimiser/grammar_optimiser.jl") 

g = @csgrammar begin
    Int = 1
    Int = Int + Int
    Int = Int * Int
end

ast_1 = RuleNode(1)
ast_1_duplicate = RuleNode(1)
ast_2 = RuleNode(2, [RuleNode(1), RuleNode(1)])
ast_2_duplicate = RuleNode(2, [RuleNode(1), RuleNode(1)])
ast_3 = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])
ast_3_duplicate = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])

@testset verbose=false "compare c₁, c₂" begin
    @test ast_1 == ast_1_duplicate
    @test ast_2 == ast_2_duplicate
    @test ast_3 == ast_3_duplicate
    @test ast_1 == ast_1
end
