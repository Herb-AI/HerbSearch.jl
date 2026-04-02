@testitem "bottom_up_custom_combinators_test" setup=[HerbSearchSetup] begin
    @testset "Simple combinator" begin
        g = @csgrammar begin
            S = S + S
            S = 10
            S = 2
        end
        costs = [1.0, 1.0, 1.0]
        iter = CostBasedBottomUpIterator(g, :S; current_costs=costs, max_cost = 3.0)
        
        @test length([r for r in iter]) == 6
        iter2 = CostBasedBottomUpIterator(g, :S; current_costs=costs, max_cost = 3.0)
        
        HerbSearch.add_combinators!(iter2, [(@rulenode 1{1{1{1{UniformHole(BitVector[1, 1, 1]), 3}, 3}, 3}, 3}, [UniformHole(BitVector[0, 0, 1])])])
        all_with_added = [r for r in iter2]
        @test length(all_with_added) == 10
        
    end 
end