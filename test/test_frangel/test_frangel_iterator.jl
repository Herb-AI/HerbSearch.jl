g = @cfgrammar begin
    Num = |(0:10)
    Num = x | (Num + Num) | (Num - Num) | (Num * Num)
end

@testset "basic_example" begin
    spec = [IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5]
    problem = Problem(spec)
    iterator = FrAngelIterator(g, :Num, max_depth=5, spec, FrAngelConfig())

    solution, flag = synth(problem, iterator)
    program = rulenode2expr(solution, g) # should yield 2*6 +1 
    println(program)

    # output = execute_on_input(SymbolTable(g), program, Dict(:x => 6)) 
    # @test output == 13
end