g = @csgrammar begin
    Int = 1
    Int = Int + Int
    Int = Int * Int
end
test_ast1 = RuleNode(1)
hole = Hole(get_domain(g, g.bytype[:Int]))
test_ast2 = RuleNode(2, [RuleNode(1), RuleNode(1)])
test_ast3 = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])

expected_output1 = """
%Maint AST
%Nodes
node(0, 1).
%Edges:

%Subtree 1
%Compression tree nodes
comp_root(1).
comp_node(1, 1).
%Compression tree edges:"""

expected_output2 = """
%Maint AST
%Nodes
node(0, 2).
node(1, 1).
node(2, 1).
%Edges:
edge(0, 1, 0).
edge(0, 2, 1).

%Subtree 1
%Compression tree nodes
comp_root(3).
comp_node(3, 2).
%Compression tree edges:

%Subtree 2
%Compression tree nodes
comp_root(6).
comp_node(6, 2).
comp_node(7, 1).
%Compression tree edges:
edge(6, 7, 0).

%Subtree 3
%Compression tree nodes
comp_root(9).
comp_node(9, 2).
comp_node(11, 1).
%Compression tree edges:
edge(9, 11, 1).

%Subtree 4
%Compression tree nodes
comp_root(12).
comp_node(12, 2).
comp_node(13, 1).
comp_node(14, 1).
%Compression tree edges:
edge(12, 13, 0).
edge(12, 14, 1).

%Subtree 5
%Compression tree nodes
comp_root(15).
comp_node(15, 1).
%Compression tree edges:"""

@testset verbose=true "Parse Input Class" begin
    # 𝟏 parse_number
    @testset verbose=true "Parse Number" begin
        @test HerbSearch.parse_number(5, "test1234test") == ("1234", 8)
        @test HerbSearch.parse_number(5, "test1234") == ("1234", 8)
        @test HerbSearch.parse_number(1, "1234test") == ("1234", 4)
        @test HerbSearch.parse_number(1, "1") == ("1", 1)
    end
    
    # 𝟐 parse_tree
    @testset verbose=true "Parse Tree" begin
        index, string = HerbSearch.parse_tree("2{1,1}")
        @test index == 3
        @test string == "%Maint AST\n%Nodes\nnode(0, 2).\nnode(1, 1).\nnode(2, 1).\n%Edges:\nedge(0, 1, 0).\nedge(0, 2, 1)."
        index, string = HerbSearch.parse_tree("2{2{1,1},3{1,1}}")
        @test index == 7
        @test string == "%Maint AST\n%Nodes\nnode(0, 2).\nnode(1, 2).\nnode(2, 1).\nnode(3, 1).\nnode(4, 3).\nnode(5, 1).\nnode(6, 1).\n%Edges:\nedge(0, 1, 0).\nedge(1, 2, 0).\nedge(1, 3, 1).\nedge(0, 4, 1).\nedge(4, 5, 0).\nedge(4, 6, 1)."
    end
    # 𝟑 parse_json
    @testset verbose=true "Parse JSON" begin
        subtrees = HerbSearch.enumerate_subtrees(test_ast1, g)
        subtree_set = Vector{Any}()
        subtree_set = vcat(subtree_set, subtrees)
        subtree_set = unique(subtree_set)
        output1, _ = (HerbSearch.parse_json(HerbSearch.parse_subtrees_to_json(subtree_set, test_ast1)))
        @test output1 == expected_output1

        subtrees = HerbSearch.enumerate_subtrees(test_ast2, g)
        subtree_set = Vector{Any}()
        subtree_set = vcat(subtree_set, subtrees)
        subtree_set = unique(subtree_set)
        print(subtree_set)
        output2, _ = (HerbSearch.parse_json(HerbSearch.parse_subtrees_to_json(subtree_set, test_ast2)))
        @test output2 == expected_output2
    end
end

