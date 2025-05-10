@testset verbose=true "BUBruteIterator" begin
    @testset "x + 50" begin
        g = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + 1
        end
        
        spec = [IOExample(Dict(:x => x), x + 50) for x ∈ 1:5]
        distance_function = (x, y) -> abs(x - y)
        helper_iterator = BUDepthIterator{RuleNode}(g, :Number, max_depth = 0)

        iterator = BUBruteIterator(g, :Number, distance_function, spec, helper_iterator, obs_equivalence=true)

        solution, flag = synth(Problem(spec), iterator) 
        program = rulenode2expr(solution, g)

        @test execute_on_input(grammar2symboltable(g), program, Dict(:x => 6)) == 6+50
    end
    @testset "100x" begin
        g = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + Number
        end
        
        spec = [IOExample(Dict(:x => x), 100x) for x ∈ 1:5]
        distance_function = (x, y) -> abs(x - y)
        helper_iterator = BUDepthIterator{RuleNode}(g, :Number, max_depth = 1)

        iterator = BUBruteIterator(g, :Number, distance_function, spec, helper_iterator, obs_equivalence=true)

        solution, flag = synth(Problem(spec), iterator) 
        program = rulenode2expr(solution, g)

        @test execute_on_input(grammar2symboltable(g), program, Dict(:x => 6)) == 6 * 100
    end
    @testset "x^2 + 10x + 25" begin
        g = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + Number
            Number = Number * Number
        end
        
        spec = [IOExample(Dict(:x => x), x^2 + 10x + 25) for x ∈ 1:5]
        distance_function = (x, y) -> abs(x - y)
        helper_iterator = BUDepthIterator{RuleNode}(g, :Number, max_depth = 1)

        iterator = BUBruteIterator(g, :Number, distance_function, spec, helper_iterator, obs_equivalence=true)

        solution, flag = synth(Problem(spec), iterator) 
        program = rulenode2expr(solution, g)

        @test execute_on_input(grammar2symboltable(g), program, Dict(:x => 6)) == 6^2 + 10*6 + 25
    end
end
