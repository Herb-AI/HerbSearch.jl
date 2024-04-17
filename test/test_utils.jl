@testset verbose=true "Utilities" begin

    @testset "Timed iterator" begin
        rl = []
        @timedfor i in [1,2,3] begin
            push!(rl, i)
        end 2
        @test length(rl) == 3

        @timedfor i in [1,2,3] begin
            push!(rl, i)
            sleep(2)
        end 3
        @test length(rl) == 5

    end
    
end