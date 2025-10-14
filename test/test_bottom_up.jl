using Test
using DataStructures: DefaultDict
import HerbSearch: init_combine_structure

grammars_to_test = Dict(
    "arity <= 1" => (@csgrammar begin
        Int = 1 | 2
        Int = 3 + Int
    end),
    "arity = 2" => (@csgrammar begin
        Int = 1 | 2
        Int = Int + Int
        Int = Int * Int
    end),
    "arity = 3" => (@csgrammar begin
        Int = 1
        Int = Int + Int
        Int = f(Int, Int, Int)
    end),
    "multiple types" => (@csgrammar begin
        Int = 1 | 2
        Int = Int + Int
        Char = 'a' | 'b'
        String = Char * Char
        Int = length(String)
        Int = Int * Int
    end)
)

# helper
test_with_grammars(f, grammars) = (for (name, g) in grammars; @testset "$name" f(g); end)

general_iterator_factories = Dict(
    "SizeBased"  => (g; kwargs...) -> SizeBasedBottomUpIterator(g, :Int; kwargs...),
    "DepthBased" => (g; kwargs...) -> DepthBasedBottomUpIterator(g, :Int; kwargs...),
    "CostBased"  => (g; kwargs...) -> begin
        g2 = isprobabilistic(g) ? g : init_probabilities!(g)
        CostBasedBottomUpIterator(g2, :Int; max_cost=1e12, kwargs...)
    end
)

# Use these for non-cost-specific tests (step-by-step, terminals-first, etc.)
structural_iterator_factories = Dict(
    "SizeBased"  => (g; kwargs...) -> SizeBasedBottomUpIterator(g, :Int; kwargs...),
    "DepthBased" => (g; kwargs...) -> DepthBasedBottomUpIterator(g, :Int; kwargs...)
)

# Cost-only variants (control max_cost explicitly in the tests)
cost_iterator_factory = Dict(
    "CostBased"  => (g; kwargs...) -> begin
        CostBasedBottomUpIterator(g, :Int; kwargs...)
    end
)

@testset "Bottom-Up Search" begin
@testset "Generic Bottom-Up Search Test" begin
    for (iter_name, make_iter) in general_iterator_factories
        @testset "$iter_name" begin
            @testset "Compare to DFS (same max_depth)" begin
                test_with_grammars(grammars_to_test) do g
                    for max_depth in 1:4
                        iter_bu  = make_iter(g; max_depth=max_depth)
                        iter_dfs = DFSIterator(g, :Int; max_depth=max_depth)

                        bu  = [freeze_state(p) for p in iter_bu]
                        dfs = [freeze_state(p) for p in iter_dfs]

                        @testset "max_depth=$max_depth" begin
                            @test issetequal(bu, dfs)
                            @test length(bu) == length(dfs)
                        end
                    end

                    for size in 1:4
                        iter_bu  = make_iter(g; max_size=size)
                        iter_dfs = DFSIterator(g, :Int; max_size=size)

                        bu  = [freeze_state(p) for p in iter_bu]
                        dfs = [freeze_state(p) for p in iter_dfs]

                        @testset "max_size=$size" begin
                            @test issetequal(bu, dfs)
                            @test length(bu) == length(dfs)
                        end
                    end
                end
            end

            @testset "Rooted correctly" begin
                test_with_grammars(grammars_to_test) do g
                    iter = make_iter(g; max_depth=3, max_size=6)
                    for p in iter
                        pf = freeze_state(p)
                        @test g.types[get_rule(pf)] == :Int
                    end
                end
            end

            @testset "No duplicates enumerated" begin
                test_with_grammars(grammars_to_test) do g
                    iter = make_iter(g; max_depth=3, max_size=6)
                    seen = Set{Any}()
                    nxt = Base.iterate(iter)
                    while !isnothing(nxt)
                        (p, st) = nxt
                        pf = freeze_state(p)
                        @test !in(pf, seen)
                        push!(seen, pf)
                        nxt = Base.iterate(iter, st)
                    end
                end
            end

            @testset "Respect structural limits (max_depth / max_size)" begin
                test_with_grammars(grammars_to_test) do g
                    for max_depth in 1:4
                        iter = make_iter(g; max_depth=max_depth, max_size=2*max_depth)
                        for p in iter
                            @test depth(p) ≤ get_max_depth(iter)
                            @test length(p) ≤ get_max_size(iter)
                        end
                    end
                end
            end

            @testset "Monotone measure" begin
                test_with_grammars(grammars_to_test) do g
                    max_depth = 3
                    iter_bu = make_iter(g; max_depth=max_depth, max_size=max_depth*2)
                    last_measure = -Inf
                    for p in iter_bu
                        m = HerbSearch.calc_measure(iter_bu, p)
                        @test m ≥ last_measure
                        if m > last_measure
                            last_measure = m
                        end
                    end
                end
            end

        end
    end
end

@testset "Structural Bottom-Up Search (Size/Depth only)" begin
    for (iter_name, make_iter) in structural_iterator_factories
        @testset "$iter_name" begin
            @testset "basic sanity" begin
                g = grammars_to_test["arity = 2"]
                iter = make_iter(g; max_depth=3, max_size=6)
                expected_programs = [
                    (@rulenode 1),
                    (@rulenode 2),
                    (@rulenode 3{1,1}),
                    (@rulenode 3{2,1}),
                    (@rulenode 3{1,2}),
                    (@rulenode 3{2,2})
                ]
                progs = [freeze_state(p) for (i, p) in enumerate(iter) if i ≤ 6]
                @test issetequal(progs, expected_programs)
                @test length(expected_programs) == length(progs)
            end

            @testset "populate_bank! returns exactly one terminal per type" begin
                test_with_grammars(grammars_to_test) do g
                    iter = make_iter(g; max_depth=3, max_size=4)
                    initial_addresses = populate_bank!(iter)
                    num_uniform_trees_terminals = length(unique(g.types[g.isterminal]))
                    @test length(initial_addresses) == num_uniform_trees_terminals
                end
            end

            @testset "iterate all terminals first" begin
                test_with_grammars(grammars_to_test) do g
                    iter = make_iter(g; max_depth=3, max_size=4)
                    expected_programs = RuleNode.(findall(g.isterminal .& (g.types .== (:Int))))
                    progs = [freeze_state(p) for (i, p) in enumerate(iter) if length(p) == 1]
                    @test issetequal(progs, expected_programs)
                    @test length(expected_programs) == length(progs)
                end
            end

            @testset "combine produces work after seed" begin
                test_with_grammars(grammars_to_test) do g
                    iter = make_iter(g; max_depth=4, max_size=8)
                    populate_bank!(iter)
                    state = GenericBUState(pq, init_combine_structure(iter), nothing, start, -Inf, Inf)
                    state = init_combine_structure(iter)

                    populate_bank!(iter, state)

                    combinations, state = combine(iter, state)
                    @test !isempty(combinations)
                end
            end

            @testset "duplicates not added to bank" begin
                all_progs(bank) = (p for m in HerbSearch.get_measures(bank)
                                     for t in HerbSearch.get_types(bank, m)
                                     for p in HerbSearch.get_programs(bank, m, t))
                test_with_grammars(grammars_to_test) do g
                    iter = make_iter(g; max_depth=3, max_size=6)
                    bank = get_bank(iter)
                    for p in iter
                        @test allunique(all_progs(bank))
                    end
                end
            end

            @testset "duplicates not enumerated + remaining_combinations unique" begin
                test_with_grammars(grammars_to_test) do g
                    iter = make_iter(g; max_depth=3, max_size=6)
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

        end
    end
end

@testset "Cost-Based Bottom-Up Search" begin
    for (iter_name, make_iter) in cost_iterator_factory
        @testset "$iter_name" begin
            @testset "populate_bank! seeds and yields terminals in first horizon" begin
                test_with_grammars(grammars_to_test) do g
                    iter = make_iter(g; max_depth=3, max_cost=1e6)
                    initial_addrs = populate_bank!(iter)
                    # Expect at least some terminals within the first horizon
                    @test !isempty(initial_addrs)

                    # And the first enumerate wave should be terminals only
                    solver = get_solver(iter)
                    start  = get_tree(solver)
                    st = GenericBUState(initial_addrs, nothing, nothing, start, -Inf, Inf)

                    # Collect only the first wave (exactly the preloaded addresses)
                    got = Any[]
                    for a in initial_addrs
                        p, st = Base.iterate(iter, st)
                        push!(got, p)
                    end
                    @test all(length(p) == 1 for p in got)
                end
            end

            @testset "max_cost prunes results (small cap)" begin
                test_with_grammars(grammars_to_test) do g
                    # Use a tiny max_cost; expect either empty or only the cheapest terminals
                    iter = make_iter(g; max_depth=5, max_cost=0.0)
                    # Enumerate a handful
                    progs = [p for (i, p) in enumerate(iter) if i ≤ 5]
                    # All programs seen (if any) must be terminals (since any op adds positive cost)
                    @test all(length(p) == 1 for p in progs)
                end
            end

            @testset "works with probabilities (init_probabilities!)" begin
                test_with_grammars(grammars_to_test) do g
                    # Use the factory: it already calls maybe_init_probabilities!
                    iter = make_iter(g; max_depth=3, max_cost=1e6)
                    # Just smoke test a few solutions
                    progs = [freeze_state(p) for (i, p) in enumerate(iter) if i ≤ 10]
                    @test !isempty(progs)
                    @test all(g.types[get_rule(pf)] == :Int for pf in progs)
                end
            end

        end
    end
end
end