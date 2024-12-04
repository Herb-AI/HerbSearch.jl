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

ast_2           = RuleNode(2, [RuleNode(1), RuleNode(1)])
ast_2_duplicate = RuleNode(2, [RuleNode(1), RuleNode(1)])

ast_3           = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])
ast_3_duplicate = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])

@testset verbose=false "Compare c₁, c₂" begin
    @test compare(ast_1, ast_1_duplicate)
    @test compare(ast_2, ast_2_duplicate)
    @test compare(ast_3, ast_3_duplicate)
    @test compare(ast_1, ast_1)
end

@testset verbose=false "Select compressions" begin
    # Make dictionary with RuleNode(1)=>(size=3, occurences=4), RuleNode(2, [RuleNode(1), RuleNode(1)])=>(size=1, occurences=1)
    c = Dict{RuleNode, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}(
        ast_1 => (size = 1, occurences = 4),
        ast_2 => (size = 3, occurences = 3),
        ast_3 => (size = 7, occurences = 2))

    @test select_compressions(1, c, 0) == []
    @test select_compressions(2, c, 1) == [ast_3, ast_2]
    @test select_compressions(1, c, 1) == [ast_2, ast_3]
    @test select_compressions(2, c, 0.5) == [ast_3]
    @test select_compressions(1, c, 0.5) == [ast_2]
end

@testset verbose=false "Get compression size" begin
    Subtree_dict = Dict{Int64, NamedTuple{(:comp_id, :parent_id, :child_nr, :type, :children), <:Tuple{Int64,Int64,Int64,Int64,Vector}}}(
        2 => (comp_id = 2, parent_id = -1, child_nr = -1, type = 2, children = [3, 5]),
        3 => (comp_id = 2, parent_id = 2, child_nr = 1, type = 2, children = []),
        5 => (comp_id = 2, parent_id = 2, child_nr = 2, type = 4, children = []),
        7 => (comp_id = 7, parent_id = -1, child_nr = -1, type = 0, children = [8,9]),
        8 => (comp_id = 7, parent_id = 7, child_nr = 0, type = 1, children = []),
        9 => (comp_id = 7, parent_id = 7, child_nr = 1, type = 1, children = []),
    )

    @test getCompressionSize(Subtree_dict, 2) == 3
    @test getCompressionSize(Subtree_dict, 7) == 3
    @test getCompressionSize(Subtree_dict, 1) == 0
end

@testset verbose=true "Zip Stats" begin
    stats = Vector{Dict{RuleNode, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}}()
    push!(stats, Dict(RuleNode(1) => (size = 1, occurences = 1), RuleNode(2) => (size = 2, occurences = 2)))
    push!(stats, Dict(RuleNode(2) => (size = 2, occurences = 2), RuleNode(3) => (size = 3, occurences = 3)))
    push!(stats, Dict(RuleNode(3) => (size = 3, occurences = 3), RuleNode(1) => (size = 1, occurences = 1)))
    stats_zipped = Dict(RuleNode(1) => (size = 1, occurences = 2), RuleNode(2) => (size = 2, occurences = 4), RuleNode(3) => (size = 3, occurences = 6))
    @test zip_stats(stats) == stats_zipped
end

@testset verbose=true "Generate Stats" begin
    Subtree_dict = Dict{Int64, NamedTuple{(:comp_id, :parent_id, :child_nr, :type, :children), <:Tuple{Int64,Int64,Int64,Int64,Vector}}}(
        2 => (comp_id = 2, parent_id = -1, child_nr = -1, type = 2, children = [3, 5]),
        3 => (comp_id = 2, parent_id = 2, child_nr = 1, type = 2, children = []),
        5 => (comp_id = 2, parent_id = 2, child_nr = 2, type = 4, children = []),
        7 => (comp_id = 7, parent_id = -1, child_nr = -1, type = 0, children = [8,9]),
        8 => (comp_id = 7, parent_id = 7, child_nr = 0, type = 1, children = []),
        9 => (comp_id = 7, parent_id = 7, child_nr = 1, type = 1, children = []),
    )
    c_ast = ["assign(2, x)", "assign(3, x)", "assign(5, x)", "assign(8, x)", "assign(9, x)", "assign(7, x)", "assign(8, x)", "assign(9, x)", "assign(7, x)"]
    c_info = Dict{Int64, NamedTuple{(:size, :occurences), <:Tuple{Int64, Int64}}}(
        7 => (size = 3, occurences = 2), 
        2 => (size = 3, occurences = 1)
    )
    @test generate_stats(Subtree_dict, c_ast) == c_info
end