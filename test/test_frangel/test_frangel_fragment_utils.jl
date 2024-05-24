using Logging
using LegibleLambdas
disable_logging(LogLevel(1))

grammar::ContextSensitiveGrammar = @cfgrammar begin
    Num = |(0:9)
    Num = (Expression + Expression) | (Expression - Expression)
    Num = max(Num, Num)
    Expression = Num | Variable
    Variable = x
    InnerStatement = (global Variable = Expression) | (InnerStatement; InnerStatement)
    Statement = (global Variable = Expression)
    Statement = (
        i = 0;
        while i < Num
            InnerStatement
            global i = i + 1
        end)
    Statement = (Statement; Statement)
    Return = return Expression
    Program = Return | (Statement; Return)
end

@testset "mine_fragments" begin
    @testset "Finds the correct fragments" begin
        # program = begin
        #     global x = 8
        #     return 7
        # end
        program = RuleNode(23, [
            RuleNode(19, [
                RuleNode(16),
                RuleNode(14, [
                    RuleNode(9)
                ])
            ]),
            RuleNode(22, [
                RuleNode(14, [
                    RuleNode(8)
                ])
            ])
        ])
        fragments = mine_fragments(grammar, program)
        fragments = delete!(fragments, program)
        expected_fragments = Set{RuleNode}([
            RuleNode(19, [
                RuleNode(16),
                RuleNode(14, [
                    RuleNode(9)
                ])
            ]),
            RuleNode(16),
            RuleNode(14, [
                RuleNode(9)
            ]),
            RuleNode(9),
            RuleNode(22, [
                RuleNode(14, [
                    RuleNode(8)
                ])
            ]),
            RuleNode(14, [
                RuleNode(8)
            ]),
            RuleNode(8)
        ])

        @test expected_fragments == fragments
    end

    @testset "Returns a disjoint set" begin
        # Not proper/compilable programs, but sufficient for testing the functionality
        # program1 = return 7 + x
        # program2 = return 8 + x
        program1 = RuleNode(22, [
            RuleNode(14, [
                RuleNode(11, [
                    RuleNode(14, [
                        RuleNode(8)
                    ]),
                    RuleNode(15, [
                        RuleNode(16)
                    ])
                ])
            ])
        ])
        program2 = RuleNode(22, [
            RuleNode(14, [
                RuleNode(11, [
                    RuleNode(14, [
                        RuleNode(9)
                    ]),
                    RuleNode(15, [
                        RuleNode(16)
                    ])
                ])
            ])
        ])
        fragments = mine_fragments(grammar, Set{RuleNode}([program1, program2]))
        expected_fragments = Set{RuleNode}([
            RuleNode(14, [
                RuleNode(11, [
                    RuleNode(14, [
                        RuleNode(8)
                    ]),
                    RuleNode(15, [
                        RuleNode(16)
                    ])
                ])
            ]),
            RuleNode(14, [
                RuleNode(11, [
                    RuleNode(14, [
                        RuleNode(9)
                    ]),
                    RuleNode(15, [
                        RuleNode(16)
                    ])
                ])
            ]),
            RuleNode(11, [
                RuleNode(14, [
                    RuleNode(8)
                ]),
                RuleNode(15, [
                    RuleNode(16)
                ])
            ]),
            RuleNode(11, [
                RuleNode(14, [
                    RuleNode(9)
                ]),
                RuleNode(15, [
                    RuleNode(16)
                ])
            ]),
            RuleNode(14, [
                RuleNode(8)
            ]),
            RuleNode(14, [
                RuleNode(9)
            ]),
            RuleNode(15, [
                RuleNode(16)
            ]),
            RuleNode(8),
            RuleNode(9),
            RuleNode(16)
        ])

        @test expected_fragments == fragments
    end
end

@testset "remember_programs" begin
    g = @cfgrammar begin
        Num = |(0:10)
        Num = x | (Num + Num) | (Num - Num) | (Num * Num)
    end
    base_g = deepcopy(g)

    # Add first remembered program
    first_program = RuleNode(13, [RuleNode(2), RuleNode(3)])
    first_program_tests = BitVector([1, 0, 1])
    first_program_value = (first_program, count_nodes(g, first_program), length(string(rulenode2expr(first_program, g))))
    old_remembered = Dict{BitVector,Tuple{RuleNode,Int,Int}}()
    remember_programs!(old_remembered, first_program_tests, first_program, rulenode2expr(first_program, g), Vector{RuleNode}(), g)

    # Second program to consider
    longer_program = RuleNode(13, [RuleNode(13, [RuleNode(1), RuleNode(2)]), RuleNode(1)])
    longer_program_value = (longer_program, count_nodes(g, longer_program), length(string(rulenode2expr(longer_program, g))))

    same_length_program = RuleNode(13, [RuleNode(1), RuleNode(2)])
    same_length_program_value = (same_length_program, count_nodes(g, same_length_program), length(string(rulenode2expr(same_length_program, g))))

    shorter_program = RuleNode(1)
    shorter_program_value = (shorter_program, count_nodes(g, shorter_program), length(string(rulenode2expr(shorter_program, g))))

    function one_test_case(new_program::RuleNode, passing_tests::BitVector, expected_result::Dict{BitVector,Tuple{RuleNode,Int,Int}})
        new_remembered = deepcopy(old_remembered)
        remember_programs!(new_remembered, passing_tests, new_program, rulenode2expr(new_program, g), Vector{RuleNode}(), g)
        @test expected_result == new_remembered
    end

    @testset "New programs pass a superset of tests" begin
        superset_tests = BitVector([1, 1, 1])
        # Longer program
        one_test_case(longer_program, superset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            first_program_tests => first_program_value, # Old program kept
            superset_tests => longer_program_value # New program added
        ))
        # Same-length program
        one_test_case(same_length_program, superset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            superset_tests => same_length_program_value # Old program replaced
        ))
        # Shorter program
        one_test_case(shorter_program, superset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            superset_tests => shorter_program_value # Old program replaced
        ))
    end

    @testset "New programs pass same set of tests" begin
        # Longer program
        one_test_case(longer_program, first_program_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            first_program_tests => first_program_value # Old program kept
        ))
        # Same-length program
        one_test_case(same_length_program, first_program_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            first_program_tests => first_program_value # Old program kept
        ))
        # Shorter program
        one_test_case(shorter_program, first_program_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            first_program_tests => shorter_program_value # Old program replaced
        ))
    end

    @testset "New programs pass a subset of tests" begin
        subset_tests = BitVector([1, 0, 0])
        # Longer program
        one_test_case(longer_program, subset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            first_program_tests => first_program_value # Old program kept
        ))
        # Same-length program
        one_test_case(same_length_program, subset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            first_program_tests => first_program_value # Old program kept
        ))
        # Shorter program
        one_test_case(shorter_program, subset_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            first_program_tests => first_program_value, # Old program kept
            subset_tests => shorter_program_value # New program added
        ))
    end

    @testset "New programs pass a disjoint set of tests" begin
        disjoint_tests = BitVector([0, 1, 1])
        # Longer program
        one_test_case(longer_program, disjoint_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            first_program_tests => first_program_value, # Old program kept
            disjoint_tests => longer_program_value # New program added
        ))
        # Same-length program
        one_test_case(same_length_program, disjoint_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            first_program_tests => first_program_value, # Old program kept
            disjoint_tests => same_length_program_value # New program added
        ))
        # Shorter program
        one_test_case(shorter_program, disjoint_tests, Dict{BitVector,Tuple{RuleNode,Int,Int}}(
            first_program_tests => first_program_value, # Old program replaced
            disjoint_tests => shorter_program_value # New program added
        ))
    end
end

@testset "add fragments as rules to grammar" begin
    grammar = @cfgrammar begin
        Program = Return | (Statement; Return) | Fragment_Program
        Return = return Expression
        Statement = Expression | (Statement; Statement)
        Expression = Num
        Num = |(0:9) | (Num + Num) | (Num - Num) | Fragment_Num
    end
    old_size = length(grammar.rules)
    add_rules!(grammar, [RuleNode(15)])

    @test length(grammar.rules) == old_size + 1

end