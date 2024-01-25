@testset verbose=true "Search procedure" begin
    g₁ = @csgrammar begin
        Number = |(1:2)
        Number = x
        Number = Number + Number
        Number = Number * Number
    end

    @testset "Search" begin
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])
        iterator = BFSIterator(g₁, :Number, max_depth=5)

        solution, flag = synth(problem, iterator)
        program = rulenode2expr(solution, g₁)

        @test execute_on_input(SymbolTable(g₁), program, Dict(:x => 6)) == 2*6+1
    end

    @testset "Search max_enumerations stopping condition" begin
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5])

        iterator = BFSIterator(g₁, :Number, max_enumerations=5)
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
        solution, flag = synth(problem, iterator, allow_evaluation_errors=true)

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
        iterator = BFSIterator(g₃, :Index, 2)
        solution, flag = synth(problem, iterator) 

        println("solution: ", solution)
        @test solution ≡ nothing
        @test flag == suboptimal_program
    end
end
