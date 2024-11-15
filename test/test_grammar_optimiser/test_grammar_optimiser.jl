using Test, HerbCore, HerbGrammar, HerbConstraints
#Cannot use "using HerbSearch" because HerbSearch does not expose this functionality. 
include("../../src/grammar_optimiser/grammar_optimiser.jl") 



# hole = Hole(get_domain(dummy_grammar, g.bytype[:Int]))

dummy_ast1 = RuleNode(2, [RuleNode(1), RuleNode(1)])
dummy_ast2 = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])
dummy_asts = [dummy_ast1, dummy_ast2]

@testset verbose=false "Integration Test: Grammar Optimiser, 3->4 Rules" begin
    # Test Values
    dummy_grammar = @csgrammar begin
        Int = 1
        Int = Int + Int
        Int = Int * Int
    end
    optimised_grammar = grammar_optimiser(dummy_asts, dummy_grammar, 1, 0.5, 0)

    # Test whether the optimised grammar has the correct number of rules (4) 
    @test length(optimised_grammar.rules) == 4
    # Test whether the added rule is 1+1
    @test optimised_grammar.rules[4] == :(1 + 1)
    # Test whether the added rule is of the correct type
    @test optimised_grammar.types[4] == :Int

end

@testset verbose=false "Integration Test: Grammar Optimiser, No rules added" begin
    # Test Values
    dummy_grammar = @csgrammar begin
        Int = 1
        Int = Int + Int
        Int = Int * Int
    end
    @test length(dummy_grammar.rules) == 3
    optimised_grammar = grammar_optimiser([RuleNode(1)], dummy_grammar, 1, 0.5, 0)

    # Test whether the optimised grammar has the correct number of rules (3) 
    @test length(optimised_grammar.rules) == 3
end
