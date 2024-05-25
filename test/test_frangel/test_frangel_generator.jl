@testset "modify_and_replace_program_fragments!" begin

    function one_test_case(fragment::RuleNode, rule_to_add::Expr, use_entire_fragment_chance::Int, program_to_modify::RuleNode, expected_program::RuleNode)
        # Setup
        grammar = deepcopy(@cfgrammar begin
            Program = Return | (Statement; Return)
            Return = return Expression
            Statement = Expression | (Statement; Statement)
            Expression = Num
            Num = |(0:9) | (Num + Num) | (Num - Num)
        end)
        fragment_base_rules_offset::Int16 = length(grammar.rules)
        add_fragment_base_rules!(grammar)
        fragment_rules_offset::Int16 = length(grammar.rules)
        add_rule!(grammar, rule_to_add)
        fragments = [fragment]

        add_fragments_prob!(grammar, Float16(0.5), fragment_base_rules_offset, fragment_rules_offset)

        rule_minsize = rules_minsize(grammar)
        rule_minsize[19:22] .= 255
        rule_minsize[23:24] .= 6

        symbol_minsize = symbols_minsize(grammar, rule_minsize)
        symbol_minsize[:Fragment_Program] = 6

        config = FrAngelConfigGeneration(use_entire_fragment_chance=use_entire_fragment_chance)

        # execute
        program = modify_and_replace_program_fragments!(program_to_modify, fragments, fragment_base_rules_offset, fragment_rules_offset, config, grammar, rule_minsize, symbol_minsize)
        # verify
        @test program == expected_program
    end

    @testset "replaces fragment at top level with entire fragment" begin
        one_test_case(
            RuleNode(1, [RuleNode(3, [RuleNode(6, [RuleNode(17, [RuleNode(8), RuleNode(9)])])])]), # return (1 + 2)
            :(Fragment_Program = return (1 + 2)), 1,
            RuleNode(23, [RuleNode(24)]), # program = fragment_program
            RuleNode(1, [RuleNode(3, [RuleNode(6, [RuleNode(17, [RuleNode(8), RuleNode(9)])])])]) # return (1 + 2)
        )
    end

    @testset "replaces fragment at lower level with entire fragment" begin
        one_test_case(
            RuleNode(18, [RuleNode(9), RuleNode(10)]), # (2 - 3)
            :(Fragment_Num = 1 + 2), 1,
            RuleNode(1, [RuleNode(4, [RuleNode(6, [RuleNode(21, [RuleNode(24)])])])]), # program = fragment_num
            RuleNode(1, [RuleNode(4, [RuleNode(6, [RuleNode(18, [RuleNode(9), RuleNode(10)])])])]) # program = (2 - 3)
        )
    end

    @testset "replaces fragment at top level with modified fragment" begin
        one_test_case(
            RuleNode(1, [RuleNode(3, [RuleNode(6, [RuleNode(17, [RuleNode(8), RuleNode(9)])])])]), # return (1 + 2)
            :(Fragment_Program = return (1 + 2)), 0,
            RuleNode(23, [RuleNode(24)]), # program = fragment_program
            RuleNode(1, [RuleNode(3, [RuleNode(6, [RuleNode(11)])])]) # return 4
        )
    end
end

@testset "add_angelic_conditions!" begin
    @testset "replaces rules with holes for angelic conditions" begin
        # setup
        grammar = @cfgrammar begin
            Program = Return | (Statement; Return)
            Return = return Expression
            Statement = Expression | (Statement; Statement)
            Expression = Num
            Num = |(0:9) | (Num + Num) | (Num - Num)
        end
        fragment_base_rules_offset::Int16 = length(grammar.rules)
        add_fragment_base_rules!(grammar)
        fragment_rules_offset::Int16 = length(grammar.rules)
        add_fragments_prob!(grammar, Float16(0.5), fragment_base_rules_offset, fragment_rules_offset)

        config = FrAngelConfig(generation=FrAngelConfigGeneration(use_angelic_conditions_chance=1))

        program = RuleNode(2, [RuleNode(4, [RuleNode(6, [RuleNode(7)])]), RuleNode(3, [RuleNode(6, [RuleNode(8)])])])

        angelic_conditions = AbstractVector{Union{Nothing,Int}}([nothing for rule in grammar.rules])
        angelic_conditions[2] = 1

        # execute
        program = add_angelic_conditions!(program, grammar, angelic_conditions, config.generation)

        # verify
        expected = RuleNode(2, [Hole(grammar.domains[return_type(grammar, 4)]), RuleNode(3, [RuleNode(6, [RuleNode(8)])])])
        @test string(program) == string(expected)
    end
end