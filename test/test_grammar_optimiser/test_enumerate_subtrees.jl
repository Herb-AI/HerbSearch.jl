using Test, HerbCore, HerbGrammar, HerbConstraints
#Cannot use "using HerbSearch" because HerbSearch does not expose this functionality. 
include("../../src/grammar_optimiser/enumerate_subtrees.jl") 

# Test Values
test_grammar = @csgrammar begin
    Int = 1
    Int = Int + Int
    Int = Int * Int
end
test_ast1 = RuleNode(1)
test_ast2 = RuleNode(2, [RuleNode(1), RuleNode(1)])
test_ast3 = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])



@testset verbose=true "Enumerate Subtrees" begin
    # Test enumerate subtrees
    test = enumerate_subtrees(test_ast1, test_grammar)
    test2 = enumerate_subtrees(test_ast2, test_grammar)
    test3 = enumerate_subtrees(test_ast3, test_grammar)
    print(enumerate_subtrees(test_ast1, test_grammar))
    # enumerate_subtrees(test_ast2, test_grammar)
    # enumerate_subtrees(test_ast3, test_grammar)

    # Test combinations
    # Test selection_criteria

end
