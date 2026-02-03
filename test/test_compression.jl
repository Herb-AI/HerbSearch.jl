CompressionExt = Base.get_extension(HerbSearch, :CompressionExt)
using .CompressionExt: refactor_grammar
using Test

grammar = @csgrammar begin
    Int = 1
    Int = Int + Int
    Int = Int * Int
    Int = Int - Int
    Int = Int / Int
    Int = 1 + Num
    Int = 1 + Int
    Num = 3
    Num = 4
    Num = 5
    Int = Num
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
        new_grammar, _ = refactor_grammar(useful_asts, grammar, 1, 10, 60)
        @test new_grammar.rules[12] == Expr(:call, :+, 1, Expr(:call, :+, 1, :Num))
    end


    @testset "Compression 1+(Int _)" begin
        # 1 + (1 + (Int (Num 4)))
        # 1 + (1 + (Int (Num 5)))
        ast1 = RuleNode(2, [RuleNode(1), RuleNode(7, [RuleNode(11, [RuleNode(8)])])])
        ast2 = RuleNode(2, [RuleNode(1), RuleNode(7, [RuleNode(11, [RuleNode(9)])])])
        ast3 = RuleNode(2, [RuleNode(1), RuleNode(7, [RuleNode(11, [RuleNode(10)])])])
        useful_asts = [ast1, ast2, ast3]
        new_grammar, _ = refactor_grammar(useful_asts, grammar, 1, 10, 60)
        @test new_grammar.rules[12] == Expr(:call, :+, 1, Expr(:call, :+, 1, :Num))
    end

    @testset "Compression fail - nothing to extract" begin
        # Program 1: 1 + 1
        # Program 2: 1 * 1
        ast1 = RuleNode(2, [RuleNode(1), RuleNode(1)])
        ast2 = RuleNode(3, [RuleNode(1), RuleNode(1)])
        useful_asts = [ast1, ast2]
        _, new_rules = refactor_grammar(useful_asts, grammar, 1, 10, 60)
        @test new_rules == []
    end

    @testset "Compression - multiple" begin
        # Program 1: (1 + 1) + ((1 - 1) + (1 - 1))
        # Program 2: (1 + 1) + ((1 * 1) + (1 * 1))
        # Program 3: (1 + 1) + ((1 / 1) + (1 / 1))
        ast1 = RuleNode(2, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(3, [RuleNode(1), RuleNode(1)]),RuleNode(3, [RuleNode(1), RuleNode(1)])])])
        ast2 = RuleNode(2, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(4, [RuleNode(1), RuleNode(1)]),RuleNode(4, [RuleNode(1), RuleNode(1)])])])
        ast3 = RuleNode(2, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(5, [RuleNode(1), RuleNode(1)]),RuleNode(5, [RuleNode(1), RuleNode(1)])])])
        useful_asts = [ast1, ast2, ast3]
        new_grammar, _ = refactor_grammar(useful_asts, grammar, 2, 10, 60)
        @test new_grammar.rules[12] == Expr(:call, :-, 1, 1)
        @test new_grammar.rules[13] == Expr(:call, :+, Expr(:call, :+, 1, 1), Expr(:call, :+, :Int, :Int))
    end

    @testset "Compression - 1+_" begin
        # (1 + (1 + 1))
        # (1 + (1 - 1))
        # 1 + 1
        ast1 = RuleNode(2, [RuleNode(1), RuleNode(2, [RuleNode(1), RuleNode(1)])])
        ast2 = RuleNode(2, [RuleNode(1), RuleNode(4, [RuleNode(1), RuleNode(1)])])
        ast3 = RuleNode(2, [RuleNode(1), RuleNode(1)])
        useful_asts = [ast1, ast2, ast3]
        new_grammar, _ = refactor_grammar(useful_asts, grammar, 2, 10, 60)
        @test new_grammar.rules[12] == Expr(:call, :+, 1, 1)
    end

end