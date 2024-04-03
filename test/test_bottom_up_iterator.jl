@testset verbose=true "Bottom-up iterator" begin
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

        iterator = BasicIterator(g, :initExpr, problem)
        solution, flag = synth(problem, iterator) 
        program = rulenode2expr(solution, g)

        @test execute_on_input(SymbolTable(g), program, Dict(:x => (1, 2))) == 1
        @test execute_on_input(SymbolTable(g), program, Dict(:x => (2, 1))) == 1
    end
    @testset "2x + 1" begin
        g = @csgrammar begin
            Int = 0 | 1 | x
            Int = Int + Int
        end
        
        problem = Problem([IOExample(Dict(:x => a), 2a + 1) for a in [0, 1, 2, 3]])        

        iterator = BasicIterator(g, :initExpr, problem)
        solution, flag = synth(problem, iterator) 
        program = rulenode2expr(solution, g)

        @test execute_on_input(SymbolTable(g), program, Dict(:x => 10)) == 21
        @test execute_on_input(SymbolTable(g), program, Dict(:x => 15)) == 31
    end
end