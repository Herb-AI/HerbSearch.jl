RefactorExt = Base.get_extension(HerbSearch, :RefactorExt)
using .RefactorExt: occurrences, occurrences_and_size, select_compressions, get_compression_size, generate_stats, zip_stats

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

@testset verbose=false "Select compressions" begin
    # Create dictionary with RuleNode(1)=>(size=3, occurrences=4), RuleNode(2, [RuleNode(1), RuleNode(1)])=>(size=1, occurrences=1)
    c = Dict{RuleNode, NamedTuple{(:size,:occurrences), <:Tuple{Int64,Int64}}}(
        ast_1 => (size = 1, occurrences = 4),
        ast_2 => (size = 3, occurrences = 3),
        ast_3 => (size = 7, occurrences = 2))

    @test select_compressions(occurrences, c, 0) == []
    @test select_compressions(occurrences_and_size, c, 1) == [ast_3, ast_2]
    @test select_compressions(occurrences, c, 1) == [ast_2, ast_3]
    @test select_compressions(occurrences_and_size, c, 0.5) == [ast_3]
    @test select_compressions(occurrences, c, 0.5) == [ast_2]
end

@testset verbose=false "Get compression size" begin
    subtree_dict = Dict{Int64, NamedTuple{(:comp_id, :parent_id, :child_nr, :type, :children), <:Tuple{Int64,Int64,Int64,Int64,Vector}}}(
        2 => (comp_id = 2, parent_id = -1, child_nr = -1, type = 2, children = [3, 5]),
        3 => (comp_id = 2, parent_id = 2, child_nr = 1, type = 2, children = []),
        5 => (comp_id = 2, parent_id = 2, child_nr = 2, type = 4, children = []),
        7 => (comp_id = 7, parent_id = -1, child_nr = -1, type = 0, children = [8,9]),
        8 => (comp_id = 7, parent_id = 7, child_nr = 0, type = 1, children = []),
        9 => (comp_id = 7, parent_id = 7, child_nr = 1, type = 1, children = []),
    )

    @test get_compression_size(subtree_dict, 2) == 3
    @test get_compression_size(subtree_dict, 7) == 3
    @test get_compression_size(subtree_dict, 1) == 0
end

@testset verbose=true "Zip Stats" begin
    stats = Vector{Dict{RuleNode, NamedTuple{(:size,:occurrences), <:Tuple{Int64,Int64}}}}()
    push!(stats, Dict(RuleNode(1) => (size = 1, occurrences = 1), RuleNode(2) => (size = 2, occurrences = 2)))
    push!(stats, Dict(RuleNode(2) => (size = 2, occurrences = 2), RuleNode(3) => (size = 3, occurrences = 3)))
    push!(stats, Dict(RuleNode(3) => (size = 3, occurrences = 3), RuleNode(1) => (size = 1, occurrences = 1)))
    stats_zipped = Dict(RuleNode(1) => (size = 1, occurrences = 2), RuleNode(2) => (size = 2, occurrences = 4), RuleNode(3) => (size = 3, occurrences = 6))
    @test zip_stats(stats) == stats_zipped
end

@testset verbose=true "Generate Stats" begin
    subtree_dict = Dict{Int64, NamedTuple{(:comp_id, :parent_id, :child_nr, :type, :children), <:Tuple{Int64,Int64,Int64,Int64,Vector}}}(
        2 => (comp_id = 2, parent_id = -1, child_nr = -1, type = 2, children = [3, 5]),
        3 => (comp_id = 2, parent_id = 2, child_nr = 1, type = 2, children = []),
        5 => (comp_id = 2, parent_id = 2, child_nr = 2, type = 4, children = []),
        7 => (comp_id = 7, parent_id = -1, child_nr = -1, type = 0, children = [8,9]),
        8 => (comp_id = 7, parent_id = 7, child_nr = 0, type = 1, children = []),
        9 => (comp_id = 7, parent_id = 7, child_nr = 1, type = 1, children = []),
    )
    c_ast = ["assign(2, x)", "assign(3, x)", "assign(5, x)", "assign(8, x)", "assign(9, x)", "assign(7, x)", "assign(8, x)", "assign(9, x)", "assign(7, x)"]
    c_info = Dict{Int64, NamedTuple{(:size, :occurrences), <:Tuple{Int64, Int64}}}(
        7 => (size = 3, occurrences = 2), 
        2 => (size = 3, occurrences = 1)
    )
    @test generate_stats(subtree_dict, c_ast) == c_info
end
