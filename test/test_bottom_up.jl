import HerbSearch.init_combine_structure

@testset "Bottom Up Search" begin
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

    function test_with_grammars(f, grammars)
        for (name, g) in grammars
            @testset "$name" f(g)
        end
    end

    @programiterator mutable MyBU(bank) <: BottomUpIterator

    function HerbSearch.init_combine_structure(iter::MyBU)
        Dict(:max_combination_depth => 10)
    end

    # observationally equivalent bottom up
    @programiterator mutable OEBU(bank) <: BottomUpIterator

    function HerbSearch.init_combine_structure(::OEBU)
        Dict(:max_combination_depth => 10)
    end

    function HerbSearch.add_to_bank!(iter::OEBU, program::AbstractRuleNode, address::AccessAddress)::Bool
        bank = HerbSearch.get_bank(iter)
        bank_location = bank[address.addr[1]][address.addr[2]]
        # bank is a nested container with 3 levels
        # level 1: size of program
        # level 2: type of program
        # level 3: separate uniform trees
        grammar = get_grammar(iter.solver)
        sizes_in_bank = values(bank)
        types_in_sizes = (t for s in sizes_in_bank for t in values(s))
        trees_in_bank = (t for trees in types_in_sizes for t in trees)
        exprs_in_trees_in_bank = (p for t in trees_in_bank for p in UniformIterator(UniformSolver(grammar, t), iter))
        return_values_in_bank = [eval(rulenode2expr(ex, grammar)) for ex in exprs_in_trees_in_bank]

        any_unseen = false

        for p in UniformIterator(UniformSolver(grammar, program), iter)
            pf = freeze_state(p)
            ex = rulenode2expr(pf, grammar)
            current_return_value = eval(ex)
            if current_return_value ∈ return_values_in_bank
                c = Forbidden(pf)
                if c ∉ grammar.constraints
                    addconstraint!(grammar, c)
                end
            else
                any_unseen = true
            end
        end

        if !any_unseen
            push!(bank_location, program)
        end

        return any_unseen
    end

    @testset "Basic Bottom Up Iterator" begin
        @testset "basic" begin
            g = grammars_to_test["arity = 2"]
            iter = MyBU(g, :Int, nothing; max_depth=5)
            expected_programs = [
                (@rulenode 1),
                (@rulenode 2),
                (@rulenode 3{1,1}),
                (@rulenode 3{2,1}),
                (@rulenode 3{1,2}),
                (@rulenode 3{2,2})
            ]

            progs = [freeze_state(p) for (i, p) in enumerate(iter) if i <= 6]
            @test issetequal(progs, expected_programs)
            @test length(expected_programs) == length(progs)
        end

        @testset "step-by-step tests" begin
            test_with_grammars(grammars_to_test) do g
                iter = MyBU(g, :Int, nothing; max_depth=3)

                @testset "populate_bank!" begin
                    create_bank!(iter)
                    initial_addresses = populate_bank!(iter)
                    num_uniform_trees_terminals = length(unique(g.types[g.isterminal]))

                    @test length(initial_addresses) == num_uniform_trees_terminals
                end

                @testset "iterate all terminals first" begin
                    expected_programs = RuleNode.(findall(g.isterminal .& (g.types .== (:Int))))

                    progs = [freeze_state(p) for (i, p) in enumerate(iter) if length(p) == 1]
                    @test issetequal(progs, expected_programs)
                    @test length(expected_programs) == length(progs)
                end
            end
        end

        @testset "combine" begin
            test_with_grammars(grammars_to_test) do g
                iter = MyBU(g, :Int, nothing; max_depth=5)
                create_bank!(iter)
                populate_bank!(iter)

                combinations, state = combine(iter, init_combine_structure(iter))
                @test !isempty(combinations)
            end
        end

        @testset "duplicates not added to bank" begin
            test_with_grammars(grammars_to_test) do g
                iter = MyBU(g, :Int, nothing; max_depth=3)

                for p in iter
                    @test allunique(Iterators.flatten(values(iter.bank)))
                end
            end
        end

        @testset "duplicates not enumerated" begin
            test_with_grammars(grammars_to_test) do g
                iter = MyBU(g, :Int, nothing; max_depth=3)

                progs = []

                next_iter = Base.iterate(iter)

                while !isnothing(next_iter)
                    (p, state) = next_iter
                    pf = freeze_state(p)
                    @testset "$pf" begin
                        push!(progs, pf)
                        @test allunique(progs)
                        @test allunique(remaining_combinations(state))
                    end
                    next_iter = Base.iterate(iter, state)
                end
            end
        end

        @testset "Strictly increasing depth" begin
            test_with_grammars(grammars_to_test) do g
                for iter_depth in 1:3
                    iter_bu = MyBU(g, :Int, nothing; max_depth=iter_depth)

                    current_depth = 0

                    for p in iter_bu
                        d = depth(p)
                        @test d >= current_depth

                        if d > current_depth
                            current_depth = d
                        end
                    end
                end
            end
        end

        @testset "Rooted correctly" begin
            test_with_grammars(grammars_to_test) do g
                for iter_depth in 1:3
                    iter_bu = MyBU(g, :Int, nothing; max_depth=iter_depth)

                    for p in iter_bu
                        pf = freeze_state(p)
                        @testset "$pf" begin
                            @test g.types[get_rule(pf)] == :Int
                        end
                    end
                end
            end
        end

        @testset "Compare to DFS" begin
            test_with_grammars(grammars_to_test) do g
                for depth in 1:3
                    iter_bu = MyBU(g, :Int, nothing; max_depth=depth)
                    iter_dfs = DFSIterator(g, :Int; max_depth=depth)

                    bottom_up_programs = [freeze_state(p) for p in iter_bu]
                    dfs_programs = [freeze_state(p) for p in iter_dfs]

                    @testset "max_depth=$depth" begin
                        @test issetequal(bottom_up_programs, dfs_programs)
                        @test length(bottom_up_programs) == length(dfs_programs)
                    end
                end
            end
        end
    end

    @testset "Example with Observational Equivalence" begin
        @testset "Strictly increasing depth" begin
            test_with_grammars(grammars_to_test) do g
                for iter_depth in 1:3
                    iter_bu = OEBU(g, :Int, nothing; max_depth=iter_depth)

                    current_depth = 0

                    for p in iter_bu
                        d = depth(p)
                        @test d >= current_depth

                        if d > current_depth
                            current_depth = d
                        end
                    end
                end
            end
        end

        @testset "duplicates not enumerated" begin
            test_with_grammars(grammars_to_test) do g
                iter = OEBU(g, :Int, nothing; max_depth=3)

                progs = []

                next_iter = Base.iterate(iter)

                while !isnothing(next_iter)
                    (p, state) = next_iter
                    pf = freeze_state(p)
                    @testset "$pf" begin
                        push!(progs, pf)
                        @test allunique(progs)
                        @test allunique(remaining_combinations(state))
                    end
                    next_iter = Base.iterate(iter, state)
                end
            end
        end

        @testset "Fewer" begin
            test_with_grammars(grammars_to_test) do g
                iter_no_obs_eq = MyBU(g, :Int, nothing; max_depth=3)
                iter_obs_eq = OEBU(g, :Int, nothing; max_depth=3)

                @test length(iter_obs_eq) < length(iter_no_obs_eq)
            end
        end

        @testset "Constraints applied" begin
            # no return value is repeated when iterating over "arity <= 1" grammar
            # observational equality encountered -> so no constraints are added
            filtered_grammars = filter(((k, _),) -> k != "arity <= 1", grammars_to_test)
            test_with_grammars(filtered_grammars) do g
                iter_obs_eq = OEBU(g, :Int, nothing; max_depth=3)

                @test length(iter_obs_eq) > 0
                @test length(get_grammar(iter_obs_eq.solver).constraints) > 0
            end
        end
    end
end