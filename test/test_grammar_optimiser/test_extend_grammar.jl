using Test, HerbCore, HerbGrammar, HerbConstraints
#Cannot use "using HerbSearch" because HerbSearch does not expose this functionality. 
include("../../src/grammar_optimiser/extend_grammar.jl")

Subtree_dict = Dict{Int64, NamedTuple{(:comp_id, :parent_id, :child_nr, :type, :children), <:Tuple{Int64,Int64,Int64,Int64,Vector{Int64}}}}(
    5 => (comp_id = 5, parent_id = -1, child_nr = -1, type = 5, children = Int64[]),
    16 => (comp_id = 14, parent_id = 14, child_nr = 1, type = 1, children = Int64[]),
    20 => (comp_id = 20, parent_id = -1, child_nr = -1, type = 5, children = [21, 22]),
    8 => (comp_id = 8, parent_id = -1, child_nr = -1, type = 5, children = [10]),
    17 => (comp_id = 17, parent_id = -1, child_nr = -1, type = 5, children = [18]),
    22 => (comp_id = 20, parent_id = 20, child_nr = 1, type = 1, children = Int64[]),
    11 => (comp_id = 11, parent_id = -1, child_nr = -1, type = 5, children = Int64[]),
    14 => (comp_id = 14, parent_id = -1, child_nr = -1, type = 5, children = [16]),
    21 => (comp_id = 20, parent_id = 20, child_nr = 0, type = 2, children = Int64[]),
    10 => (comp_id = 8, parent_id = 8, child_nr = 1, type = 1, children = Int64[]),
    18 => (comp_id = 17, parent_id = 17, child_nr = 0, type = 2, children = Int64[])
)

g = @cfgrammar begin
    Number = |(1:2)
    Number = x
    Number = Number + Number 
    Number = Number * Number
end
hole = Hole(get_domain(g, g.bytype[:Number]))
test_ast = RuleNode(4, [RuleNode(1), hole])

@testset verbose=true "Generate Tree From Compression" begin
    tree = generate_tree_from_compression(20, Subtree_dict, 20, g)
    @test string(tree) == string(RuleNode(5, [RuleNode(2),RuleNode(1)])) 

    tree = generate_tree_from_compression(17, Subtree_dict, 17, g)
    @test string(tree) == string(RuleNode(5, [RuleNode(2),hole]))

    tree = generate_tree_from_compression(11, Subtree_dict, 11, g)
    @test string(tree) == string(RuleNode(5, [hole,hole])) 
end

@testset verbose=true "Extend Grammar" begin 
    result = extend_grammar(test_ast, g).rules[6]
    @test result == :(1 + Number)
end

