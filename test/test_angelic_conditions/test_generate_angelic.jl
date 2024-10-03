grammar = @cfgrammar begin
    Num = |(0:10)
    Num = x | (Num + Num)
    Bool = Num == Num
    Num = (
        if Bool
            Num
        else
            Num
        end
    )
    Angelic = update_✝_angelic_path
end

spec = [
    IOExample(Dict(:x => 1), 2)
    IOExample(Dict(:x => 2), 3)
    IOExample(Dict(:x => 3), 3)
    IOExample(Dict(:x => 4), 5)
    IOExample(Dict(:x => 5), 6)
    IOExample(Dict(:x => 6), 7)
]
problem = Problem(spec)
rules_min = rules_minsize(grammar)
symbol_min = symbols_minsize(grammar, rules_min)
angelic_conditions = Dict{UInt16,UInt8}()
angelic_conditions[15] = 1

(fragment_base_rules_offset, fragment_rules_offset) = setup_grammar_with_fragments!(grammar, Float16(0.5))

@testset "add_angelic_conditions! and replace_first_angelic!" begin
    p = RuleNode(1)
    state = nothing
    while p.ind != 15
        p = rand(RuleNode, grammar, :Num)
    end
    println("Program to be 'angelified': ", p)
    p = add_angelic_conditions!(p, grammar, angelic_conditions)
    println("Program after 'angelification': ", p)

    @test contains_hole(p) && number_of_holes(p) == 1

    new_tests = BitVector([false for _ in 1:5])
    boolean_expr = rand(RuleNode, grammar, :Bool, 3)
    replace_first_angelic!(p, boolean_expr, RuleNode(0), Dict{UInt16,UInt8}(15 => 1))
    @test !contains_hole(p)
end