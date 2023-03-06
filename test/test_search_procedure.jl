@testset verbose=true "Search procedure" begin
    g₁ = @cfgrammar begin
        Number = |(1:5)
        Number = x
        Number = Number + Number
        Number = Number * Number
        Number = Number - Number
    end

    @testset "Search" begin
        problem = Problem([IOExample(Dict(:x => x), 3x+2) for x ∈ 1:5], "")
        solution = search(g₁, problem, :Number, max_depth=3)

        @test test_with_input(SymbolTable(g₁), solution, Dict(:x => 6)) == 3*6+2
    end

    @testset "Search max_enumerations stopping condition" begin
        problem = Problem([IOExample(Dict(:x => x), 3x+2) for x ∈ 1:5], "")
        solution = search(g₁, problem, :Number, max_enumerations=5)

        @test solution ≡ nothing
    end

    @testset "Best search" begin
        problem = Problem(push!([IOExample(Dict(:x => x), 3x+2) for x ∈ 1:5], IOExample(Dict(:x => 5), 15)), "")
        solution, correctness = search_best(g₁, problem, :Number, max_depth=3)

        @test correctness ≈ 5/6
        @test test_with_input(SymbolTable(g₁), solution, Dict(:x => 6)) == 3*6+2

    end

    @testset "Search_best max_enumerations stopping condition" begin
        problem = Problem([IOExample(Dict(:x => x), 3x-2) for x ∈ 1:5], "")
        solution, correctness = search_best(g₁, problem, :Number, max_enumerations=5)

        @test solution == 1 || solution == 4
        @test correctness == 1/5 
    end
end