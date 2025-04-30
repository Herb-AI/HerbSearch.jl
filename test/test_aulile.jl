
@testset "Aulile" begin
    g = @csgrammar begin
        Number = |(1:2)
        Number = x
        Number = Number + Number
        Number = Number * Number
    end
    
    problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])
    iterator = BFSIterator(g, :Number, max_depth=5)
    
    solution, flag = synth(problem, iterator)
    program = rulenode2expr(solution, g)
    println(program)
    
    output = execute_on_input(grammar2symboltable(g), program, Dict(:x => 6)) 
    println(output)

    @test true
end