@testset verbose=true "@iterator macro" begin
    g = @csgrammar begin
        R = x
    end

    s  = :R
    max_depth = 5
    max_size = 5
    solver = nothing
    
    abstract type IteratorFamily <: ProgramIterator end

    @testset "no inheritance" begin
        @programiterator LonelyIterator(
            f1::Int,
            f2
        )

        # 2 arguments + 1 hidden solver argument = 3
        @test fieldcount(LonelyIterator) == 3
        
        lit = LonelyIterator(g, s, max_depth = max_depth, max_size = max_size, 2, :a)
        @test lit.solver.grammar == g && lit.f1 == 2 && lit.f2 == :a
        @test LonelyIterator <: ProgramIterator
    end

    @testset "with inheritance" begin
        @programiterator ConcreteIterator(
            f1::Bool,
            f2
        ) <: IteratorFamily

        it = ConcreteIterator(g, s, max_depth = max_depth, max_size = max_size, true, 4)

        @test ConcreteIterator <: IteratorFamily
        @test it.f1 && it.f2 == 4
    end

    @testset "mutable iterator" begin
        @programiterator mutable AnotherIterator() <: IteratorFamily


        it = AnotherIterator(g, s, max_depth = 10, max_size = 5)

        @test it.solver.max_depth == 10
        @test it.solver.max_size == 5 
        @test AnotherIterator <: IteratorFamily
    end

    @testset "with default values" begin
        @programiterator DefValIterator(
            a::Int=5,
            b=nothing
        )

        it = DefValIterator(g, :R)

        @test it.a == 5 && isnothing(it.b)
        @test it.solver.max_depth == typemax(Int)

        it = DefValIterator(g, :R, max_depth=5)

        @test it.solver.max_depth == 5
    end
    @testset "Check if max_depth and max_size are overwritten" begin 

        solver = GenericSolver(g, :R, max_size=10, max_depth=5)
        @test solver.max_size == 10
        @test solver.max_depth == 5
        # will overwrite solver.max_depth from 5 to 3. But keeps solver.max_size=10.
        iterator = BFSIterator(solver = solver, max_depth=3) 
        @test get_max_size(solver) == 10 
        @test get_max_depth(solver) == 3
    end

    @testset "Check default constructors with a solver" begin 
        solver = GenericSolver(g, :R, max_size=10, max_depth=5)
        iterator = BFSIterator(solver)
        @test get_grammar(iterator.solver) == g 
        @test get_max_size(iterator.solver) == 10 
        @test get_max_depth(iterator.solver) == 5
    end
end
