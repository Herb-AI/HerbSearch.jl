@testset "Bottom Up Search" begin
    mutable struct MyBU <: BottomUpIterator
        grammar
        starts
        bank
    end

    g = @csgrammar begin
        Int = 1 | 2
        Int = Int + Int
    end
    
    iter = MyBU(g, :Int, nothing)
    expected_programs = Set([
        (@rulenode 1),
        (@rulenode 2),
        (@rulenode 3{1, 1}),
        (@rulenode 3{2, 1}),
        (@rulenode 3{1, 2}),
        (@rulenode 3{2, 2})
    ])

    progs = Set(collect(iter)[1:6])
    @test progs == expected_programs
end