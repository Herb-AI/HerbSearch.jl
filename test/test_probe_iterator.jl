@testset verbose=true "Probe" begin
    @testset "2x + 1" begin
        g = @csgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end
        
        spec = [IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5]
        iterator = ProbeIterator(g, :Number, spec, obs_equivalence=true)

        solution, flag = synth(Problem(spec), iterator) 
        program = rulenode2expr(solution, g)

        @test execute_on_input(grammar2symboltable(g), program, Dict(:x => 6)) == 2*6+1
    end
end