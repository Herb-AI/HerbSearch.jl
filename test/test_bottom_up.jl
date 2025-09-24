import HerbSearch.init_combine_structure
using DataStructures: DefaultDict


grammars_to_test = Dict(
    "arity <= 1" => (@csgrammar begin
        Int = 1 | 2
        Int = 3 + Int
    end),
    "arity = 2" => (@csgrammar begin
        Int = 1 | 2
        Int = Int + Int
    end),
    "multiple types" => (@csgrammar begin
        Int = 1 | 2
        Int = Int + Int
        Char = 'a' | 'b'
        String = Char * Char
        Int = length(String)
        Int = Int * Int
    end),
    "binary operators simple" => (@csgrammar begin
        Int = 1
        Int = Int + Int
        Int = Int * Int
    end)
)

iterator_factories = Dict(
    "SizeBased"  => (g; kwargs...) -> SizeBasedBottomUpIterator(g, :Int; kwargs...),
    "DepthBased" => (g; kwargs...) -> DepthBasedBottomUpIterator(g, :Int; kwargs...),
    "CostBased"  => (g; kwargs...) -> CostBasedBottomUpIterator(g, :Int, max_cost=20; kwargs...)
)

"""
Loops over all iterator factories × grammars, creating a nested @testset.
Write the test once, and it runs for every (iterator, grammar).
"""
function test_with_iterators(factories, grammars; kwargs..., f)
    for (iname, factory) in factories
        @testset "$iname iterator" begin
            for (gname, g) in grammars
                @testset "$gname" begin
                    iter = factory(g; kwargs...)
                    f(iter, g, iname)
                end
            end
        end
    end
end

@testset "Bottom Up Search" begin

    @testset "basic" begin
        subset = selectkeys(grammars_to_test, ["arity = 2"])
        test_with_iterators(iterator_factories, subset; max_depth=5) do iter, g, iname
            progs = [freeze_state(p) for (i, p) in enumerate(iter) if i <= 6]

            # Instead of exact order, check basic invariants:
            # - we only get :Int rooted programs
            # - first programs include all Int terminals
            @test all(g.types[get_rule(p)] == :Int for p in progs)

            terminals = RuleNode.(findall(g.isterminal .& (g.types .== (:Int))))
            @test all(t ∈ progs for t in terminals)

            # sanity: at least one non-terminal shows up too
            @test any(length(p) > 1 for p in progs)
        end
    end

    @testset "Step-by-step tests" begin
        test_with_iterators(iterator_factories, grammars_to_test; max_depth=3) do iter, g, _
            @testset "Check populate_bank!" begin
                initial_addresses = populate_bank!(iter)
                num_uniform_trees_terminals = length(unique(g.types[g.isterminal]))
                @test length(initial_addresses) == num_uniform_trees_terminals
            end

            @testset "Iterate all terminals first" begin
                expected_programs = RuleNode.(findall(g.isterminal .& (g.types .== (:Int))))
                progs = [freeze_state(p) for (i, p) in enumerate(iter) if length(p) == 1]
                @test issetequal(progs, expected_programs)
            end
        end
    end

    @testset "Combine" begin
        test_with_iterators(iterator_factories, grammars_to_test; max_depth=5) do iter, g, _
            populate_bank!(iter)
            combinations, state = combine(iter, init_combine_structure(iter))
            @test !isempty(combinations)
        end
    end

    @testset "duplicates not added to bank" begin
        all_progs(bank) = (p for m in HerbSearch.get_measures(bank)
                             for t in HerbSearch.get_types(bank, m)
                             for p in HerbSearch.get_programs(bank, m, t))
        test_with_iterators(iterator_factories, grammars_to_test; max_depth=3) do iter, g, _
            bank = get_bank(iter)
            for p in iter
                @test allunique(all_progs(bank))
            end
        end
    end

    @testset "duplicates not enumerated" begin
        test_with_iterators(iterator_factories, grammars_to_test; max_depth=3) do iter, g, _
            progs = []
            next_iter = Base.iterate(iter)
            while !isnothing(next_iter)
                (p, state) = next_iter
                pf = freeze_state(p)
                push!(progs, pf)
                @test allunique(progs)
                @test allunique(remaining_combinations(state))
                next_iter = Base.iterate(iter, state)
            end
        end
    end

    @testset "Strictly increasing depth" begin
        test_with_iterators(iterator_factories, grammars_to_test) do iter, g, factory
            for iter_depth in 1:4
                iter_bu = iterator_factories[factory](g; max_depth=iter_depth)
                current_depth = 0
                for p in iter_bu
                    d = depth(p)
                    @test d >= current_depth
                    current_depth = max(d, current_depth)
                end
            end
        end
    end

    @testset "Rooted correctly" begin
        test_with_iterators(iterator_factories, grammars_to_test) do iter, g, factory
            for iter_depth in 1:4
                iter_bu = iterator_factories[factory](g; max_depth=iter_depth)
                for p in iter_bu
                    pf = freeze_state(p)
                    @test g.types[get_rule(pf)] == :Int
                end
            end
        end
    end

    @testset "Compare to DFS" begin
        test_with_iterators(iterator_factories, grammars_to_test) do iter, g, factory
            for depth in 1:4
                iter_bu = iterator_factories[factory](g; max_depth=depth)
                iter_dfs = DFSIterator(g, :Int; max_depth=depth)
                bottom_up_programs = [freeze_state(p) for p in iter_bu]
                dfs_programs = [freeze_state(p) for p in iter_dfs]
                @test issetequal(bottom_up_programs, dfs_programs)
            end
        end
    end
end