@testset verbose=true "Search procedure" begin
    g₁ = @cfgrammar begin
        Number = |(1:2)
        Number = x
        Number = Number + Number
        Number = Number * Number
    end

    @testset "Search" begin
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5], "")
        solution = search(g₁, problem, :Number, max_depth=3)

        @test test_with_input(SymbolTable(g₁), solution, Dict(:x => 6)) == 2*6+1
    end

    @testset "Search max_enumerations stopping condition" begin
        problem = Problem([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5], "")
        solution = search(g₁, problem, :Number, max_enumerations=5)

        @test solution ≡ nothing
    end

    @testset "Search with errors in evaluation" begin
        g₂ = @cfgrammar begin
            Number = 1
            List = []
            Index = List[Number]
        end
        
        problem = Problem([IOExample(Dict(), x) for x ∈ 1:5], "")
        solution = search(g₂, problem, :Index, max_depth=2, allow_evaluation_errors=true)

        @test solution ≡ nothing
    end

    @testset "Best search" begin
        problem = Problem(push!([IOExample(Dict(:x => x), 2x+1) for x ∈ 1:5], IOExample(Dict(:x => 5), 15)), "")
        solution, error = search_best(g₁, problem, :Number, max_depth=3)

        @test error == 1
        @test test_with_input(SymbolTable(g₁), solution, Dict(:x => 6)) == 2*6+1

    end

    @testset "Search_best max_enumerations stopping condition" begin
        problem = Problem([IOExample(Dict(:x => x), 2x-1) for x ∈ 1:5], "")
        solution, error = search_best(g₁, problem, :Number, max_enumerations=2)

        @test solution == 1
        @test error == 4
    end

    @testset "Search_best with errors in evaluation" begin
        g₃ = @cfgrammar begin
            Number = 1
            List = []
            Index = List[Number]
        end
        
        problem = Problem([IOExample(Dict(), x) for x ∈ 1:5], "")
        solution, error = search_best(g₃, problem, :Index, max_depth=2, allow_evaluation_errors=true)

        @test solution ≡ nothing
        @test error == typemax(Int)
    end
end