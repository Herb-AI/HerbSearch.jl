@testset verbose=true "@iterator macro" begin
    g = @csgrammar begin
        R = x
    end

    s  = :R
    md = 5
    ms = 5
    mt = 5
    me = 5
    solver = nothing
    
    abstract type IteratorFamily <: ProgramIterator end

    @testset "no inheritance" begin
        @programiterator LonelyIterator(
            f1::Int,
            f2
        )

        @test fieldcount(LonelyIterator) == 9
        
        lit = LonelyIterator(g, s, md, ms, mt, me, solver, 2, :a)
        @test lit.grammar == g && lit.f1 == 2 && lit.f2 == :a
        @test LonelyIterator <: ProgramIterator
    end

    @testset "with inheritance" begin
        @programiterator ConcreteIterator(
            f1::Bool,
            f2
        ) <: IteratorFamily

        it = ConcreteIterator(g, s, md, ms, mt, me, solver, true, 4)

        @test ConcreteIterator <: IteratorFamily
        @test it.f1 && it.f2 == 4
    end

    @testset "mutable iterator" begin
        @programiterator mutable AnotherIterator() <: IteratorFamily

        it = AnotherIterator(g, s, md, ms, mt, me, solver)

        it.max_depth = 10

        @test it.max_depth == 10
        @test AnotherIterator <: IteratorFamily
    end

    @testset "with inner constructor" begin
        @programiterator mutable DefConstrIterator(
            function DefConstrIterator()
                g = @csgrammar begin R = x end
                new(g, :R, 5, 5, 5, 5, nothing)
            end
        )

        it = DefConstrIterator()
        
        @test it.max_enumerations == me && it.max_depth == md
    end

    @testset "with default values" begin
        @programiterator DefValIterator(
            a::Int=5,
            b=nothing
        )

        it = DefValIterator(g, :R)

        @test it.a == 5 && isnothing(it.b)
        @test it.max_depth == typemax(Int)

        it = DefValIterator(g, :R, max_depth=5)

        @test it.max_depth == 5
    end

    @testset "all together" begin
        @programiterator mutable ComplicatedIterator(
            intfield::Int,
            deffield=nothing,
            function ComplicatedIterator(g, s, md, ms, mt, me, solver, i, d) 
                new(g, s, md, ms, mt, me, solver, i, d)
            end,
            function ComplicatedIterator()
                let g = @csgrammar begin
                    R = x
                    R = 1 | 2
                end
                    new(g, :R, 1, 2, 3, 4, nothing, 5, 6)
                end
            end
        )

        it = ComplicatedIterator()

        @test length(it.grammar.rules) == 3
        @test it.sym == :R
        @test it.max_depth == 1
        @test it.intfield == 5
        @test it.deffield == 6

        it = ComplicatedIterator(g, :S, 5; max_depth=10)

        @test it.max_depth == 10
        @test length(it.grammar.rules) == 1
        @test it.sym == :S
        @test isnothing(it.deffield)
    end
end
