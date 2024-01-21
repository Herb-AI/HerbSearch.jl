@testset verbose=true "@iterator macro" begin
    g = @csgrammar begin
        R = x
    end

    s  = :R
    md = 5
    ms = 5
    mt = 5
    me = 5
    
    abstract type IteratorFamily <: ProgramIterator end

    @testset "no inheritance" begin
        @programiterator LonelyIterator(
            f1::Int,
            f2
        )

        @test fieldcount(LonelyIterator) == 8
        
        lit = LonelyIterator(g, s, md, ms, mt, me, 2, :a)
        @test lit.grammar == g && lit.f1 == 2 && lit.f2 == :a
        @test LonelyIterator <: ProgramIterator
    end

    @testset "with inheritance" begin
        @programiterator ConcreteIterator(
            f1::Bool,
            f2
        ) <: IteratorFamily

        it = ConcreteIterator(g, s, md, ms, mt, me, true, 4)

        @test ConcreteIterator <: IteratorFamily
        @test it.f1 && it.f2 == 4
    end

    @testset "mutable iterator" begin
        @programiterator mutable AnotherIterator() <: IteratorFamily

        it = AnotherIterator(g, s, md, ms, mt, me)

        it.max_depth = 10

        @test it.max_depth == 10
        @test AnotherIterator <: IteratorFamily
    end

    @testset "with default constructor" begin
        @programiterator mutable DefConstrIterator(
            function DefConstrIterator()
                g = @csgrammar R = x
                new(g, :R, 5, 5, 5, 5)
            end
        )

        it = DefConstrIterator()
        
        @test it.max_enumerations == me && it.max_depth == md
    end 
end
