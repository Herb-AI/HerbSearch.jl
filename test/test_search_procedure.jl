@testset verbose=true "Search procedure" begin
    g₁ = @csgrammar begin
        Number = |(1:2)
        Number = x
        Number = Number + Number
        Number = Number * Number
    end

    @testset "Search" begin
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])
        iterator = BFSIterator(g₁, :Number, 5, typemax(Int), typemax(Int), typemax(Int))

        solution, flag = synth(problem, iterator)
        program = rulenode2expr(solution, g₁)

        @test execute_on_input(SymbolTable(g₁), program, Dict(:x => 6)) == 2*6+1
    end

    @testset "Search max_enumerations stopping condition" begin
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])

        iterator = BFSIterator(g₁, :Number, typemax(Int), typemax(Int), typemax(Int), 5)
        solution, flag = synth(problem, iterator)

        @test Int(flag) == 2
    end

    @testset "Search with errors in evaluation" begin
        g₂ = @csgrammar begin
            Number = 1
            List = []
            Index = List[Number]
        end
        
        problem = Problem([IOExample(Dict(), x) for x ∈ 1:5])
        iterator = BFSIterator(g₂, :Index, 2, typemax(Int), typemax(Int), typemax(Int))
        solution, flag = synth(problem, iterator) #@TODO allow_evaluation_errors is broken

        @test Int(flag) == 2
    end

    @testset "Best search" begin
        problem = Problem(push!([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5], IOExample(Dict(:x => 5), 15)))
        iterator = BFSIterator(g₁, :Number, 3, typemax(Int), typemax(Int), typemax(Int))

        solution, flag = synth(problem, iterator)
        program = rulenode2expr(solution, g₁)

        @test Int(flag) = 2
        @test execute_on_input(SymbolTable(g₁), program, Dict(:x => 6)) == 2*6+1

    end

    @testset "Search_best max_enumerations stopping condition" begin
        problem = Problem([IOExample(Dict(:x => x), 2x-1) for x ∈ 1:5])
        iterator = BFSIterator(g₁, :Number, typemax(Int), typemax(Int), typemax(Int), 2)

        solution, flag = synth(problem, iterator)
        program = rulenode2expr(solution, g₁)

        @test solution == 1
        @test Int(flag) == 2
    end

    @testset "Search_best with errors in evaluation" begin
        g₃ = @csgrammar begin
            Number = 1
            List = []
            Index = List[Number]
        end
        
        problem = Problem([IOExample(Dict(), x) for x ∈ 1:5])
        solution, error = search_best(g₃, problem, :Index, max_depth=2, allow_evaluation_errors=true)

        @test solution ≡ nothing
        @test error == typemax(Int)
    end
end
