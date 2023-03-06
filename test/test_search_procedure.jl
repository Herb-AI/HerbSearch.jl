@testset verbose=true "Search procedure" begin
    g₁ = @cfgrammar begin
        Number = |(0:4)
        Number = x
        Number = Number + Number
        Number = Number * Number
    end

    @testset "Search" begin
        problem = Problem([IOExample(Dict(:x => x), 3x+2) for x ∈ 1:5], "")
        solution = search(g₁, problem, 3, :Number)

        @test test_with_input(SymbolTable(g₁), solution, Dict(:x => 6)) == 3*6+2
    end

    @testset "Best search" begin
        problem = Problem(push!([IOExample(Dict(:x => x), 3x+2) for x ∈ 1:5], IOExample(Dict(:x => 5), 15)), "")
        solution, correctness = search_best(g₁, problem, 3, :Number)

        @test correctness ≈ 5/6
        @test test_with_input(SymbolTable(g₁), solution, Dict(:x => 6)) == 3*6+2

    end
end