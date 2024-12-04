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
    # Testing the combinations function
    @testset verbose=true "Verify Combinations" begin
        combinations1 = combinations(1)
        @test length(combinations1) == 2
        @test combinations1 == [[true], [false]]
        combinations2 = combinations(2)
        @test length(combinations2) == 4
        @test combinations2 == [[true, true], [true, false], [false, true], [false, false]]
        combinations3 = combinations(3)
        @test length(combinations3) == 8
        @test combinations3 == [[true, true, true], [true, true, false], [true, false, true], [true, false, false], [false, true, true], [false, true, false], [false, false, true], [false, false, false]]       
    end
    @testset verbose=true "Verify Large Combinations" begin
        combinations_large = combinations(10)
        @test length(combinations_large) == 1024
        # Assert that there is the same amount of true as false in the combinations
        @test length(filter(x -> x == true, vcat(combinations_large...))) == length(filter(x -> x == false, vcat(combinations_large...)))
    end
    # Testing the selection_criteria function
    @testset verbose=true "Verify Selection Criteria" begin
        selection1 = selection_criteria(test_ast1, test_ast1)
        @test (selection1 == false) #Size is same as the input
        selection2 = selection_criteria(test_ast2, test_ast1)
        @test (selection2 == false) #Subtree has size of one
        @test (selection_criteria(test_ast2, test_ast2) == false) #Subtree has same size as input
        @test (selection_criteria(test_ast3, test_ast2) == true)
    end
    # Testing the enumerate_subtrees function
    @testset verbose=true "Verify Enumerate Subtrees" begin
        subtrees = enumerate_subtrees(test_ast1, test_grammar)
        @test length(subtrees) == 1
        
        subtrees2 = enumerate_subtrees(test_ast2, test_grammar)
        @test test_ast1 ∈ subtrees2
        @test test_ast2 ∈ subtrees2
        subtrees2 = filter(subtree -> selection_criteria(test_ast2, subtree), subtrees2) #remove subtrees size 1 and treesize
        @test test_ast1 ∉ subtrees2
        @test test_ast2 ∉ subtrees2

        subtrees3 = enumerate_subtrees(test_ast3, test_grammar)
        @test length(subtrees3) == 37
        @test test_ast1 ∈ subtrees3
        @test test_ast2 ∈ subtrees3
        subtrees3 = filter(subtree -> selection_criteria(test_ast3, subtree), subtrees3) #remove subtrees size 1 and treesize
        @test length(subtrees3) == 17
        @test test_ast1 ∉ subtrees3
        @test test_ast2 ∈ subtrees3
    end
end
