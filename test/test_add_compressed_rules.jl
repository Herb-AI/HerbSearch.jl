CompressionExt = Base.get_extension(HerbSearch, :CompressionExt)
using .CompressionExt: split_hole, create_new_exprs

grammar = @csgrammar begin
    Int = 1
    Int = 2
    Int = Op
    Op = Int + Int
    Op = Int - Int
end

@testset "splitter_test" begin
    @testset "operation hole" begin
        hole_rule = UniformHole([0, 0, 0, 1, 1], [RuleNode(1), RuleNode(2)])
        splits = split_hole(hole_rule, grammar)
        @test length(splits) == 2
        @test rulenode2expr(splits[1], grammar) == :(1 + 2)
    end

    @testset "operation and arguments hole" begin
        hole_rule = UniformHole([0, 0, 0, 1, 1], [UniformHole([1, 1, 0, 0, 0]), RuleNode(2)])
        splits = split_hole(hole_rule, grammar)
        @test length(splits) == 4
    end

    @testset "operation is a hole, child is an int" begin
        hole_rule = UniformHole([0, 0, 0, 1, 1], [UniformHole([1, 1, 1, 0, 0]), RuleNode(2)])
        splits = split_hole(hole_rule, grammar)
        @test length(splits) == 2
        @test rulenode2expr(splits[1], grammar) == :(Int + 2)
    end

    @testset "no split" begin
        no_holes = RuleNode(4, [RuleNode(1), RuleNode(2)])
        splits = split_hole(no_holes, grammar)
        @test rulenode2expr(only(splits), grammar) == rulenode2expr(no_holes, grammar)
    end
end

@testset "make_new_rules" begin
    @testset "leave same" begin
        no_holes = RuleNode(4, [RuleNode(1), RuleNode(2)])
        new_exprs = create_new_exprs(no_holes, grammar, 1)
        @test only(new_exprs)[2] == :(Op = 1 + 2)
    end

    @testset "operation hole" begin
        hole_rule = UniformHole([0, 0, 0, 1, 1], [RuleNode(1), RuleNode(2)])
        new_exprs = create_new_exprs(hole_rule, grammar, 1)
        @test length(new_exprs) == 3
        @test new_exprs[1][2] == :(Op = _Rule_6_1)
        @test new_exprs[2][2] == :(_Rule_6_1 = 1 + 2)
        @test new_exprs[3][2] == :(_Rule_6_1 = 1 - 2)
    end

end