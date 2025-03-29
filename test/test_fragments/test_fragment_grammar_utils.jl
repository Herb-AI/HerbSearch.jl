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
        
        add_fragment_rules!(grammar_with_fragment_placeholders, [RuleNode(8), RuleNode(9)])
        add_fragments_prob!(grammar_with_fragment_placeholders, Float16(0.6), Int16(18), Int16(20))

        expected_probabilities = Vector{Real}([0.5, 0.5])
        expected_probabilities = vcat(expected_probabilities, fill(1, 4))
        expected_probabilities = vcat(expected_probabilities, fill(Float16(1 / 30), 12))
        append!(expected_probabilities, 0, Float16(0.6), 0.5, 0.5)

        @test all(expected_probabilities .== grammar_with_fragment_placeholders.log_probabilities)
    end
end