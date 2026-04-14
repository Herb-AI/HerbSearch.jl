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
        
        HerbSearch.add_combinators!(iter2, [@rulenode 1{1{1{1{UniformHole(BitVector[1, 1, 1]), 3}, 3}, 3}, 3}])
        all_with_added = [r for r in iter2]
        @test length(all_with_added) == 10
        
    end 

    @testset "no duplicates caused by refactoring" begin
        @testset "Simple grammar" begin
            g = @csgrammar begin
                S = A
                A = B
                B = 1
            end

            oe_function(rn::RuleNode) = [1]
            costs = [1.0, 1.0, 1.0]
            iter = CostBasedBottomUpIterator(g, :S, current_costs=costs, max_cost=1.0, program_to_outputs=oe_function)
            new_rn = @rulenode 2{3}
            HerbSearch.add_new_terminals!(iter, [new_rn, @rulenode 3], [1.0, 1.0])
            all_progrs = collect(iter)
            @test allunique(all_progrs)
        end

        @testset "Not a simple grammar" begin
            g = @csgrammar begin
                S = A - B  # 1
                A = V + V  # 2 
                A = V * V  # 3
                B = V + V  # 4
                B = V * V  # 5
                V = C      # 6
                C = 1      # 7
                C = 2      # 8
                V = T      # 9
                T = :X     # 10
            end

            costs = [1.0 for _ in 1:10]
            oe_function(rn::RuleNode) = [rn]
            iter = CostBasedBottomUpIterator(g, :S, current_costs=costs, max_cost=1.0, program_to_outputs=oe_function)
            r1 = @rulenode 6{7}
            r2 = @rulenode 9{10}
            new_terms = [r1, r2]
            # HerbSearch.add_new_terminals!(iter, new_terms, [1.0, 1.0])

            all_progrs = collect(iter)
            @test allunique(all_progrs)
        end

        @testset "iterate using Base.iterate" begin
            g = @csgrammar begin
                Start = Activators - Inhibitors # 1
                Activators = Val                # 2
                Inhibitors = Val                # 3
                Val = Val + Val                 # 4
                Div = Val / Const               # 5 do not divide by Entities.
                Val = Val * Val                 # 6
                Val = Min(Val, Val)             # 7
                Val = Max(Val, Val)             # 8
                Val = Ceil(Div)                 # 9
                Val = Floor(Div)                # 10
                Val = Entity                    # 11
                Val = Const                     # 12
                Const = 0
                Const = 1
                Const = 2
                Const = 3
                Const = 4
                Entity = :X
            end

            oe_function(rn::RuleNode) = [rn]
            costs = [1.0 for _ in eachindex(g.rules)]
            @info "This might take some time ...."
            iter = CostBasedBottomUpIterator(g, :Start, current_costs=costs, max_cost = 7.1)
            HerbSearch.add_combinators!(iter, RuleNode[])
            HerbSearch.add_new_terminals!(iter, RuleNode[], Float64[])
            all_progrs = []
            
            iter_state = nothing
            
            while true
                next_val = isnothing(iter_state) ? Base.iterate(iter) : Base.iterate(iter, iter_state)
                isnothing(next_val) && break
                rn, iter_state = next_val   
                push!(all_progrs, rn)
            end
            @test allunique(all_progrs)

        end
    end 

    @testset "adding rules with holes all over" begin
        @testset "hole in the middle of a tree" begin
            g = @csgrammar begin
                A = V      # 1 
                V = V * V  # 2
                V = V + V  # 3
                V = C      # 4
                C = 1      # 5
                C = 2      # 6
                V = T      # 7
                T = :X     # 8
                S = A      # 9
            end
            nr = RuleNode(1, [UniformHole(Bool[0, 1, 1, 0, 0, 0, 0, 0, 0], [RuleNode(4, [UniformHole(Bool[0, 0, 0, 0, 1, 1, 0, 0, 0])]), RuleNode(4, [UniformHole(Bool[0, 0, 0, 0, 1, 1, 0, 0, 0])])])])  # Const(*|+)Const
            @show nr
            costs = [1.0 for _ in eachindex(g.rules)]
            oe_function(rn::RuleNode) = [rn]
            iter = CostBasedBottomUpIterator(g, :S, current_costs=costs, max_cost=7.1, program_to_outputs=oe_function)
            HerbSearch.add_combinators!(iter, [nr])
            @info "This might take some time ...."
            all_progrs = [x for x in iter]
            @show all_progrs
            @test allunique(all_progrs)
            @test (@rulenode 9{1{2{4{5}, 4{5}}}}) in all_progrs
        end

        @testset "hole at the root level" begin
            g = @csgrammar begin
                A = V      # 1 
                V = V * V  # 2
                V = V + V  # 3
                V = C      # 4
                C = 1      # 5
                C = 2      # 6
                V = T      # 7
                T = :X     # 8
                S = A      # 9
            end
            nr = UniformHole(Bool[0, 1, 1, 0, 0, 0, 0, 0, 0], [RuleNode(4, [UniformHole(Bool[0, 0, 0, 0, 1, 1, 0, 0, 0])]), RuleNode(4, [UniformHole(Bool[0, 0, 0, 0, 1, 1, 0, 0, 0])])])  # Const(*|+)Const
            @show nr
            costs = [1.0 for _ in eachindex(g.rules)]
            oe_function(rn::RuleNode) = [rn]
            iter = CostBasedBottomUpIterator(g, :S, current_costs=costs, max_cost=7.1, program_to_outputs=oe_function)
            HerbSearch.add_combinators!(iter, [nr])
            @info "This might take some time ...."
            all_progrs = [x for x in iter]
            @show all_progrs
            @test allunique(all_progrs)
            @test (@rulenode 9{1{2{4{5}, 4{5}}}}) in all_progrs
        end

        @testset "hole in a terminal" begin
            g = @csgrammar begin
                A = V      # 1 
                V = V * V  # 2
                V = V + V  # 3
                V = C      # 4
                C = 1      # 5
                C = 2      # 6
                V = T      # 7
                T = :X     # 8
                S = A      # 9
            end
            nr = UniformHole(Bool[0, 1, 1, 0, 0, 0, 0, 0, 0], [RuleNode(4, [RuleNode(5)]), RuleNode(4, [RuleNode(5)])])  # Const(*|+)Const
            costs = [1.0 for _ in eachindex(g.rules)]
            oe_function(rn::RuleNode) = [rn]
            iter = CostBasedBottomUpIterator(g, :S, current_costs=costs, max_cost=3.1, program_to_outputs=oe_function)
            HerbSearch.add_new_terminals!(iter, [nr], [1.0])
            @info "This might take some time ...."
            all_progrs = [x for x in iter]
            @show all_progrs
            @test allunique(all_progrs)
            @test (@rulenode 9{1{2{4{5}, 4{5}}}}) in all_progrs
        end

    end
      
end