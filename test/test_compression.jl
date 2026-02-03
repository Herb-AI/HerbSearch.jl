CompressionExt = Base.get_extension(HerbSearch, :CompressionExt)
using .CompressionExt: compress_programs
using Test
using JSON
using Clingo_jll

grammar = @csgrammar begin
    Int = 1             #1 
    Int = Int + Int     #2
    Int = Int * Int     #3
    Int = Int - Int     #4
    Int = Int / Int     #5
    Int = 1 + Num       #6
    Int = 1 + Int       #7
    Num = 3             #8
    Num = 4             #9
    Num = 5             #10
    Int = Num           #11
end

@testset verbose=false "Compression" begin
    @testset "Compression 1+_" begin
        # 1 + (1 + (Num 3))
        # 1 + (1 + (Num 4))
        # 1 + (1 + (Num 5))
        ast1 = RuleNode(2, [RuleNode(1), RuleNode(6, [RuleNode(8)])])
        ast2 = RuleNode(2, [RuleNode(1), RuleNode(6, [RuleNode(9)])])
        ast3 = RuleNode(2, [RuleNode(1), RuleNode(6, [RuleNode(10)])])
        useful_asts = [ast1, ast2, ast3]
        new_rules= compress_programs(useful_asts, grammar; k=1, max_compression_nodes=10, time_limit_sec=60)
        @test rulenode2expr(only(new_rules), grammar) == Expr(:call, :+, 1, Expr(:call, :+, 1, :Num))
    end


    @testset "Compression 1+(Int _)" begin
        # 1 + (1 + (Int (Num 4)))
        # 1 + (1 + (Int (Num 5)))
        ast1 = RuleNode(2, [RuleNode(1), RuleNode(7, [RuleNode(11, [RuleNode(8)])])])
        ast2 = RuleNode(2, [RuleNode(1), RuleNode(7, [RuleNode(11, [RuleNode(9)])])])
        ast3 = RuleNode(2, [RuleNode(1), RuleNode(7, [RuleNode(11, [RuleNode(10)])])])
        useful_asts = [ast1, ast2, ast3]
        new_rules = compress_programs(useful_asts, grammar; k=1, max_compression_nodes=10, time_limit_sec=60)
        @test rulenode2expr(only(new_rules), grammar) == Expr(:call, :+, 1, Expr(:call, :+, 1, :Num))
    end

    @testset "Compression fail - nothing to extract" begin
        # Program 1: 1 + 1
        # Program 2: 1 * 1
        ast1 = RuleNode(2, [RuleNode(1), RuleNode(1)])
        ast2 = RuleNode(3, [RuleNode(1), RuleNode(1)])
        useful_asts = [ast1, ast2]
        new_rules = compress_programs(useful_asts, grammar; k=1, max_compression_nodes=10, time_limit_sec=60)
        @test isempty(new_rules)
    end

    @testset "Compression - multiple" begin
        # Program 1: (1 + 1) + ((1 - 1) + (1 - 1))
        # Program 2: (1 + 1) + ((1 * 1) + (1 * 1))
        # Program 3: (1 + 1) + ((1 / 1) + (1 / 1))
        ast1 = RuleNode(2, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(3, [RuleNode(1), RuleNode(1)]),RuleNode(3, [RuleNode(1), RuleNode(1)])])])
        ast2 = RuleNode(2, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(4, [RuleNode(1), RuleNode(1)]),RuleNode(4, [RuleNode(1), RuleNode(1)])])])
        ast3 = RuleNode(2, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(5, [RuleNode(1), RuleNode(1)]),RuleNode(5, [RuleNode(1), RuleNode(1)])])])
        useful_asts = [ast1, ast2, ast3]
        new_rules = compress_programs(useful_asts, grammar; k=2, max_compression_nodes=10, time_limit_sec=60)
        @test rulenode2expr(new_rules[1], grammar) == Expr(:call, :-, 1, 1)
        @test rulenode2expr(new_rules[2], grammar) == Expr(:call, :+, Expr(:call, :+, 1, 1), Expr(:call, :+, :Int, :Int))
    end

    @testset "Compression - 1+_" begin
        # (1 + (1 + 1))
        # (1 + (1 - 1))
        # 1 + 1
        ast1 = RuleNode(2, [RuleNode(1), RuleNode(2, [RuleNode(1), RuleNode(1)])])
        ast2 = RuleNode(2, [RuleNode(1), RuleNode(4, [RuleNode(1), RuleNode(1)])])
        ast3 = RuleNode(2, [RuleNode(1), RuleNode(1)])
        useful_asts = [ast1, ast2, ast3]
        new_rules = compress_programs(useful_asts, grammar; k=1, max_compression_nodes=10, time_limit_sec=60)
        @test rulenode2expr(only(new_rules), grammar) == Expr(:call, :+, 1, :Int)
    end

end