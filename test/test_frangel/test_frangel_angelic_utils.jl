grammar = @cfgrammar begin
    Num = |(0:10)
    Num = x | (Num + Num)
    Bool = Num == Num
    Num = (if Bool ; Num else Num end)
end

@testset "angelic_utils" begin
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
    angelic_conditions = AbstractVector{Union{Nothing,Int64}}([nothing for rule in grammar.rules])
    angelic_conditions[15] = 1

    rules_min = rules_minsize(grammar)
    symbol_min = symbols_minsize(grammar, rules_min)
    angelic_conditions = AbstractVector{Union{Nothing,Int64}}([nothing for rule in grammar.rules])
    angelic_conditions[15] = 1

    config = FrAngelConfig(verbose_level=0, generation=FrAngelConfigGeneration(use_fragments_chance=0.5, use_angelic_conditions_chance=1, max_size=20))
    iterator = FrAngelRandomIterator(grammar, :Num, rules_min, symbol_min, max_depth=config.generation.max_size)
    fragment_base_rules_offset::Int16 = length(grammar.rules)
    add_fragment_base_rules!(grammar)
    fragment_rules_offset::Int16 = length(grammar.rules)
    add_fragments_prob!(grammar, config.generation.use_fragments_chance, fragment_base_rules_offset, fragment_rules_offset)
    resize!(rules_min, fragment_rules_offset)
    for i in fragment_base_rules_offset+1:fragment_rules_offset
        rules_min[i] = 255
    end

    @testset "angelic_evaluation" begin
        p = RuleNode(15, [Hole([]), RuleNode(12), RuleNode(13, [RuleNode(12), RuleNode(2)])])
        tab = SymbolTable(grammar)
        res = execute_angelic_on_input(tab, p, grammar, spec[1].in, 2, RuleNode(14, [RuleNode(1), RuleNode(1)]), config.angelic.max_execute_attempts, angelic_conditions)
        @test res
    end

    @testset "add_angelic_conditions! and replace_next_angelic" begin
        p = RuleNode(1)
        state = nothing
        while p.ind != 15
            p, state = iterate(iterator)
        end
        println("Program to be 'angelified': ", p)
        p = add_angelic_conditions!(p, grammar, angelic_conditions, config.generation)
        println("Program after 'angelification': ", p)

        @test contains_hole(p) && number_of_holes(p) == 1

        new_tests = BitVector([false for _ in 1:5])
        boolean_expr = generate_random_program(grammar, :Bool, config.generation, fragment_base_rules_offset, config.angelic.boolean_expr_max_size, rules_min, symbol_min)
        p = replace_next_angelic(p, boolean_expr, 1)
        @test !contains_hole(p)
    end
end

st = SymbolTable(g)
st[:update_✝γ_path] = update_✝γ_path

@testset "test_expression_angelic_modification_basic" begin
    expr = :(if update_✝γ_path(✝γ_code_path, ✝γ_actual_code_path) 3 else 2 end)

    @testset "falsy evaluation" begin
        opath = Vector{Char}(['0'])
        apath = Vector{Char}([])

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end
        out = execute_on_input(st, angelic_expr, Dict(:x => 0)) 

        @test out == 2
        @test apath == ['0']
    end

    @testset "truthy evaluation" begin
        opath = Vector{Char}(['1', '1'])
        apath = Vector{Char}([])

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end
        out = execute_on_input(st, angelic_expr, Dict(:x => 0)) 

        @test out == 3
        @test apath == ['1'] # Note how the attempted path is two 1s, but actual - just one (only one if-statement)
    end
end

@testset "test_expression_angelic_modification_error" begin
    st[:error] = error
    expr = :(
        if update_✝γ_path(✝γ_code_path, ✝γ_actual_code_path) 
            error("hi")
            if update_✝γ_path(✝γ_code_path, ✝γ_actual_code_path) 
                10 
            else 
                0 
            end 
        else 
            2 
        end
    )

    @testset "falsy evaluation" begin
        opath = Vector{Char}(['0'])
        apath = Vector{Char}([])

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end
        out = execute_on_input(st, angelic_expr, Dict(:x => 0)) 

        @test out == 2
        @test apath == ['0']
    end

    @testset "truthy evaluation" begin
        opath = Vector{Char}(['1', '1'])
        apath = Vector{Char}([])

        angelic_expr = quote
            ✝γ_code_path = $opath
            ✝γ_actual_code_path = $apath
            $expr
        end

        @test_throws Exception execute_on_input(st, angelic_expr, Dict(:x => 0)) # truthy case should throw an error
        @test apath == ['1'] # and not enter the if-statement afterwards
    end
end