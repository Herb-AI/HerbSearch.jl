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

        iterator = BUDepthIterator(g, :intExpr, problem)
        solution, flag = synth(problem, iterator) 
        program = rulenode2expr(solution, g)

        @test execute_on_input(SymbolTable(g), program, Dict(:x => (1, 2))) == 1
        @test execute_on_input(SymbolTable(g), program, Dict(:x => (2, 1))) == 1
    end
    @testset "2x + 1" begin
        g = @csgrammar begin
            Number = |(1:2)
            Number = x
            Number = Number + Number
            Number = Number * Number
        end
        
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])       
        iterator = BUDepthIterator(g, :Number, problem)

        solution, flag = synth(problem, iterator) 
        program = rulenode2expr(solution, g)

        @test execute_on_input(SymbolTable(g), program, Dict(:x => 6)) == 2*6+1
    end
    @testset "Arithmetic grammar iteration order" begin
        g = @csgrammar begin
            Number = |(0:1)
            Number = x
            Number = Number + Number
        end
    
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])       
        iterator = BUDepthIterator(g, :Number, problem)

        iterated_programs = []
        for (index, program) ∈ Iterators.take(enumerate(iterator), 7)
            push!(iterated_programs, rulenode2expr(program, g))
        end

        @test iterated_programs == [0, 1, :x, :(1 + 1), :(x + 1), :(x + x), :((1 + 1) + 1)]
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

        programs = collect(BUDepthIterator(grammar, :Number, problem, max_depth=2))
        @test RuleNode(4, [RuleNode(1), RuleNode(2)]) ∉ programs
    end
end
