# Test Values
g = @csgrammar begin
    Int = 1
    Int = Int + Int
    Int = Int * Int
    Int = -Int
end

hole = Hole(get_domain(g, g.bytype[:Int]))

ast1 = RuleNode(1)
ast2 = RuleNode(2, [RuleNode(1), RuleNode(1)])
ast3 = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])

@testset verbose=true "Parse Subtrees to JSON 1" begin
    dummy_subtrees::Vector{Any} = [ast1, RuleNode(2, [hole, RuleNode(1)]), RuleNode(2, [RuleNode(1), hole])]
    desired_result = "{\"ast\":\"2{1,1}\",\"subtrees\":[\"1\",\"2{_,1}\",\"2{1,_}\"]}"
    @test HerbSearch.convert_subtrees_to_json(dummy_subtrees, ast2) == desired_result
end

@testset verbose=true "Parse Subtrees to JSON 0 subtrees" begin
    desired_result = "{\"ast\":\"1\",\"subtrees\":[]}"
    @test HerbSearch.convert_subtrees_to_json([], ast1) == desired_result 
end

@testset verbose=true "Parse Subtrees to JSON 1 subtree" begin
    dummy_subtrees::Vector{Any} = [RuleNode(4, [hole])]
    desired_result = "{\"ast\":\"4{1}\",\"subtrees\":[\"4{_}\"]}"
    @test HerbSearch.convert_subtrees_to_json(dummy_subtrees, RuleNode(4, [RuleNode(1)])) == desired_result 
end