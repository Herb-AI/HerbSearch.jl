g = @cfgrammar begin
    Num = |(0:10)
    Num = x | (Num + Num)
    Bool = (Num == Num)
    Num = (if Bool ; Num else Num end)
end

@testset "basic_example" begin
    spec = [IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5]
    problem = Problem(spec)
    @time begin 
        # iterator = FrAngelIterator(g, :Num, max_depth=10, spec, FrAngelConfig(generation = FrAngelConfigGeneration( 
            # use_fragments_chance = 0, use_angelic_conditions_chance = 0)), AbstractVector{Union{Nothing, Int64}}([nothing for rule in g.rules]))
        iterator = FrAngelIterator(g, :Num, max_depth=10, spec, FrAngelConfig(), AbstractVector{Union{Nothing, Int64}}([nothing for rule in g.rules])) 
        solution, flag = synth(problem, iterator) 
    end
    program = rulenode2expr(solution, g) # should yield 2*6 +1 
    println(program)

    @time begin 
        iterator = BFSIterator(g, :Num, max_depth=10)
        solution, flag = synth(problem, iterator)
    end
    program = rulenode2expr(solution, g) # should yield 2*6 +1 
    println(program)

    # output = execute_on_input(SymbolTable(g), program, Dict(:x => 6)) 
    # @test output == 13
end