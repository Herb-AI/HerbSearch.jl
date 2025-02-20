RefactorExt = Base.get_extension(HerbSearch, :RefactorExt)
using .RefactorExt: occurrences

ast1 = RuleNode(2, [RuleNode(1), RuleNode(1)])
ast2 = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])
asts = [ast1, ast2]

@testset verbose=false "Integration Test: Grammar Refactor, 3->4 Rules" begin
    # Test Values
    g = @csgrammar begin
        Int = 1
        Int = Int + Int
        Int = Int * Int
    end
    optimised_grammar = refactor_grammar(asts, g, occurrences, 0.5)

    # Test whether the optimised grammar has the correct number of rules (4) 
    @test length(optimised_grammar.rules) == 4
    # Test whether the added rule is 1+1
    @test optimised_grammar.rules[4] == :(1 + 1)
    # Test whether the added rule is of the correct type
    @test optimised_grammar.types[4] == :Int

end

@testset verbose=false "Integration Test: Grammar Refactor, No rules added" begin
    # Test Values
    g = @csgrammar begin
        Int = 1
        Int = Int + Int
        Int = Int * Int
    end
    @test length(g.rules) == 3
    optimised_grammar = refactor_grammar([RuleNode(1)], g, occurrences, 0.5)

    # Test whether the optimised grammar has the correct number of rules (3) 
    @test length(optimised_grammar.rules) == 3
end
