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

config = FrAngelConfig(verbose_level=0, generation=FrAngelConfigGeneration(use_fragments_chance=0.5, use_angelic_conditions_chance=1, max_size=20))
iterator = FrAngelRandomIterator(grammar, :Num, rules_min, symbol_min, max_depth=config.generation.max_size)
(fragment_base_rules_offset, fragment_rules_offset) = setup_grammar_with_fragments!(grammar, config.generation.use_fragments_chance, rules_min)

@testset "add_angelic_conditions! and replace_first_angelic!" begin
    p = RuleNode(1)
    state = nothing
    while p.ind != 15
        p, state = iterate(iterator)
    end
    println("Program to be 'angelified': ", p)
    p = add_angelic_conditions!(p, grammar, angelic_conditions)
    println("Program after 'angelification': ", p)

    @test contains_hole(p) && number_of_holes(p) == 1

    new_tests = BitVector([false for _ in 1:5])
    boolean_expr = rand(RuleNode, grammar, :Bool, config.angelic.boolean_expr_max_depth)
    replace_first_angelic!(p, boolean_expr, RuleNode(0), Dict{UInt16,UInt8}(15 => 1))
    @test !contains_hole(p)
end