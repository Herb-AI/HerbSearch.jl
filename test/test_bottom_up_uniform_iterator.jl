@testset verbose=true "BUDepthIterator{UniformHole}" begin
    @testset "smallest element in a tuple" begin
        g = @csgrammar begin
            intExpr = first(x)
            intExpr = last(x)
            intExpr = 0
            intExpr = intExpr + 1
            intExpr = if(boolExpr) intExpr else intExpr end
            boolExpr = intExpr > intExpr
            boolExpr = boolExpr && boolExpr
        end
    
        problem = Problem([IOExample(Dict(:x => (fst, snd)), min(fst, snd)) for (fst, snd) in [(4, 5), (12, 14), (13, 10), (5, 1)]])        

        iterator = BUDepthIterator{UniformHole}(g, :intExpr)
        solution, flag = synth(problem, iterator) 
        program = rulenode2expr(solution, g)

        @test execute_on_input(grammar2symboltable(g), program, Dict(:x => (1, 2))) == 1
        @test execute_on_input(grammar2symboltable(g), program, Dict(:x => (2, 1))) == 1
    end
    @testset "2x + 1" begin
        g = @csgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end
        
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])       
        iterator = BUDepthIterator{UniformHole}(g, :Number)

        solution, flag = synth(problem, iterator) 
        program = rulenode2expr(solution, g)

        @test execute_on_input(grammar2symboltable(g), program, Dict(:x => 6)) == 2*6+1
    end
    @testset "Arithmetic grammar with constraints" begin
        grammar = @csgrammar begin
            Number = x | 1
            Number = Number + Number
            Number = Number - Number
        end
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])  
        
        constraint = Forbidden(RuleNode(4, [RuleNode(1), RuleNode(2)]))
        addconstraint!(grammar, constraint)

        programs = collect(BUDepthIterator{UniformHole}(grammar, :Number, max_depth=2))
        @test RuleNode(4, [RuleNode(1), RuleNode(2)]) ∉ programs
    end
end
