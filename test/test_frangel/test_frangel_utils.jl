using Logging
using LegibleLambdas
disable_logging(LogLevel(1))

grammar::ContextSensitiveGrammar = @cfgrammar begin
    Num = |(0:9)
    Num = (Num + Num) | (Num - Num)
    Num = max(Num, Num)
    Expression = Num | Variable
    Variable = x
    InnerStatement = (Variable = Expression) | (InnerStatement; InnerStatement)
    Statement = (
        i = 0;
        while i < Num
            InnerStatement
            i = i + 1
        end)
    Statement = (Statement; Statement)
    Return = return Expression
    Program = Return | (Statement; Return)
end

@testset "minsize_map" begin
    @testset "returns the correct minimum size for each rule" begin
        @test [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 3, 3, 2, 2, 1, 4, 9, 6, 13, 3, 4, 10] == rules_minsize(grammar)
    end
end

@testset "symbols_minsize" begin
    @testset "returns the correct minimum size for each symbol, based on the rules minsizes" begin
        rules_minsizes = Vector{UInt8}([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 3, 3, 2, 2, 1, 4, 9, 6, 13, 3, 4, 10])
        expected_symbol_minsizes = Dict(:Expression => 2, :Num => 1, :Statement => 6, :Variable => 1, :InnerStatement => 4, :Return => 3, :Program => 4)

        @test expected_symbol_minsizes == symbols_minsize(grammar, rules_minsizes)
    end
end

@testset "simplify_quick" begin
    @testset "swaps node with a terminal node if possible" begin
        # program = begin
        #     return (7 + (9 - 5)) - 3
        # end
        program = RuleNode(23, [
            RuleNode(22, [
                RuleNode(14, [
                    RuleNode(12, [
                        RuleNode(11, [
                            RuleNode(14, [RuleNode(8)]),
                            RuleNode(12, [
                                RuleNode(14, [RuleNode(9)]),
                                RuleNode(14, [RuleNode(6)])
                            ])
                        ])
                        RuleNode(14, [RuleNode(3)])
                    ])
                ])
            ])
        ])

        tests = [IOExample(Dict(), 8)]
        passed_tests = BitVector([true])
        
        # return 8
        expected = RuleNode(23, [RuleNode(22, [RuleNode(14, [RuleNode(9)])])])

        @test expected == simplify_quick(program, grammar, tests, passed_tests, Int16(24))
    end

    @testset "removes unnecesarry neighbour nodes" begin   
        # program = begin
        #     x = 8
        #     return 7
        # end
        program = RuleNode(24, [
            RuleNode(19, [
                RuleNode(16),
                RuleNode(14, [
                    RuleNode(9)
                ])
            ])
            RuleNode(22, [
                RuleNode(14, [
                    RuleNode(8)
                ])
            ])
        ])

        tests = [IOExample(Dict(), 7)]
        passed_tests = BitVector([true])

        # return 7
        expected = RuleNode(23, [RuleNode(22, [RuleNode(14, [RuleNode(8)])])])

        @test expected == simplify_quick(program, grammar, tests, passed_tests, Int16(24))
    end
end

@testset "add_fragments_prob!" begin
    @testset "finds the fragment placeholders and adds appropiate probabilities" begin

        grammar_with_fragment_placeholders = @cfgrammar begin
            Program = Return | (Statement; Return)
            Return = return Expression
            Statement = Expression | (Statement; Statement)
            Expression = Num
            Num = |(0:9) | (Num + Num) | (Num - Num)
            Program = Fragment_Program
            Num = Fragment_Num
            
        end
        add_rules!(grammar_with_fragment_placeholders, [RuleNode(8), RuleNode(9)])
        add_fragments_prob!(grammar_with_fragment_placeholders, Float16(0.6), Int16(18), Int16(20))  
        
        expected_probabilities = Vector{Real}([0.5, 0.5])
        expected_probabilities = vcat(expected_probabilities, fill(1, 4))
        expected_probabilities = vcat(expected_probabilities, fill(Float16(1/30), 12))
        append!(expected_probabilities, 0, Float16(0.6), 0.5, 0.5)

        @test all(expected_probabilities .== grammar_with_fragment_placeholders.log_probabilities)
    end
end