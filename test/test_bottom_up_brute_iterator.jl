@testset verbose=true "BUBruteIterator" begin
    @testset "x + 50" begin
        g = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + 1
        end
        
        spec = [IOExample(Dict(:x => x), x + 50) for x ∈ 1:5]
        distance_function = (x, y) -> abs(x - y)
        iterator = BUBruteIterator(g, :Number, distance_function, spec, obs_equivalence=true)

        solution, flag = synth(Problem(spec), iterator) 
        program = rulenode2expr(solution, g)

        @test execute_on_input(grammar2symboltable(g), program, Dict(:x => 6)) == 6+50
    end
end
