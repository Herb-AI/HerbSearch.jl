@testset "FrAngel" verbose=true begin
    include("test_frangel_fragment_utils.jl")
    include("test_frangel_utils.jl")
    include("test_frangel_iterator.jl")
    include("test_frangel_angelic_utils.jl")


    @testset "modify_and_replace_program_fragments!" begin
        @testset "replaces fragment at top level with entire fragment" begin
            # setup
            grammer_with_fragment_placeholders = @cfgrammar begin
                Program = Return | (Statement; Return) | Fragment_Program
                Return = return Expression
                Statement = Expression | (Statement; Statement)
                Expression = Num
                Num = |(0:9) | (Num + Num) | (Num - Num) | Fragment_Num
            end
            add_fragments_prob!(grammer_with_fragment_placeholders, 0.5)

            fragments_offset = length(grammer_with_fragment_placeholders.rules)

            add_rule!(grammer_with_fragment_placeholders, :(Fragment_Program = return (1 + 2)))
            fragments = [
                RuleNode(1, [RuleNode(4, [RuleNode(7, [RuleNode(18, [RuleNode(9), RuleNode(10)])])])]),
            ]

            program_with_fragments = RuleNode(3, [RuleNode(21)])

            config = FrAngelConfigGeneration(use_entire_fragment_chance = 1)
            
            rule_minsize = rules_minsize(grammar) 
            for rule_index in eachindex(grammar.rules)
                sym = grammar.types[rule_index]
            
                if isterminal(grammar, rule_index) && grammar.rules[rule_index] == Symbol(string(:Fragment_, sym))
                    rule_minsize[rule_index] = typemax(Int)
                end
            end
        
            symbol_minsize = symbols_minsize(grammar, rule_minsize)
        
            # execute
            program = modify_and_replace_program_fragments!(program_with_fragments, fragments, fragments_offset, config, grammer_with_fragment_placeholders, rule_minsize, symbol_minsize)  

            # verify
            expected = RuleNode(1, [RuleNode(4, [RuleNode(7, [RuleNode(18, [RuleNode(9), RuleNode(10)])])])])
            @test program == expected
        end

        @testset "replaces fragment at lower level with entire fragment" begin
            # setup
            grammer_with_fragment_placeholders = @cfgrammar begin
                Program = Return | (Statement; Return) | Fragment_Program
                Return = return Expression
                Statement = Expression | (Statement; Statement)
                Expression = Num
                Num = |(0:9) | (Num + Num) | (Num - Num) | Fragment_Num
            end
            add_fragments_prob!(grammer_with_fragment_placeholders, 0.5)

            fragments_offset = length(grammer_with_fragment_placeholders.rules)

            add_rule!(grammer_with_fragment_placeholders, :(Fragment_Num = 1 + 2))
            fragments = [
                RuleNode(18, [RuleNode(9), RuleNode(10)])
            ]

            program_with_fragments = RuleNode(1, [RuleNode(4, [RuleNode(7, [RuleNode(20, [RuleNode(21)])])])])

            config = FrAngelConfigGeneration(use_entire_fragment_chance = 1)
            
            rule_minsize = rules_minsize(grammar) 
            for rule_index in eachindex(grammar.rules)
                sym = grammar.types[rule_index]
            
                if isterminal(grammar, rule_index) && grammar.rules[rule_index] == Symbol(string(:Fragment_, sym))
                    rule_minsize[rule_index] = typemax(Int)
                end
            end
        
            symbol_minsize = symbols_minsize(grammar, rule_minsize)
    
            # execute
            program = modify_and_replace_program_fragments!(program_with_fragments, fragments, fragments_offset, config, grammer_with_fragment_placeholders, rule_minsize, symbol_minsize)  

            # verify
            expected = RuleNode(1, [RuleNode(4, [RuleNode(7, [RuleNode(18, [RuleNode(9), RuleNode(10)])])])])
            @test program == expected
        end
    end
end