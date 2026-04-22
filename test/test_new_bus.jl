import HerbSearch: freeze_state
using HerbConstraints

struct TestSizeIter <: AbstractBUSIterator end  # uses default node_cost = 1

struct TestCostIter <: AbstractBUSIterator
    costs::Vector{Int}
end
HerbSearch.node_cost(iter::TestCostIter, op::Int) = iter.costs[op]

@testset "assemble(prog::RuleNode, children)" begin
    # Grammar (implicit, 3 rules):
    #   rule 1: Int = 1
    #   rule 2: Int = 2
    #   rule 3: Int = Int + Int
    #
    # A Hole that allows any of the 3 rules.
    domain = trues(3)

    @testset "single hole replaced" begin
        # +(Hole, 1) filled with [2] → +(2, 1)
        prog   = RuleNode(3, [Hole(domain), RuleNode(1)])
        result = assemble(prog, [RuleNode(2)])
        @test result == RuleNode(3, [RuleNode(2), RuleNode(1)])
    end

    @testset "two holes, flat — filled left to right" begin
        # +(Hole, Hole) filled with [1, 2] → +(1, 2)
        prog   = RuleNode(3, [Hole(domain), Hole(domain)])
        result = assemble(prog, [RuleNode(1), RuleNode(2)])
        @test result == RuleNode(3, [RuleNode(1), RuleNode(2)])
    end

    @testset "depth-first: left subtree holes filled before right hole" begin
        # +(+(Hole, Hole), Hole) filled with [a, b, c]
        # depth-first: recurse into left child first → +(a, b), then right → c
        prog   = RuleNode(3, [RuleNode(3, [Hole(domain), Hole(domain)]), Hole(domain)])
        result = assemble(prog, [RuleNode(1), RuleNode(2), RuleNode(1)])
        @test result == RuleNode(3, [RuleNode(3, [RuleNode(1), RuleNode(2)]), RuleNode(1)])
    end

    @testset "depth-first: left hole filled before right subtree holes" begin
        # +(Hole, +(Hole, Hole)) filled with [a, b, c]
        # depth-first: left hole → a, then recurse into right child → +(b, c)
        prog   = RuleNode(3, [Hole(domain), RuleNode(3, [Hole(domain), Hole(domain)])])
        result = assemble(prog, [RuleNode(1), RuleNode(2), RuleNode(2)])
        @test result == RuleNode(3, [RuleNode(1), RuleNode(3, [RuleNode(2), RuleNode(2)])])
    end

    @testset "no holes — original structure preserved" begin
        prog   = RuleNode(3, [RuleNode(1), RuleNode(2)])
        result = assemble(prog, [])
        @test result == prog
    end

    @testset "original program not mutated" begin
        prog   = RuleNode(3, [Hole(domain), Hole(domain)])
        _      = assemble(prog, [RuleNode(1), RuleNode(2)])
        @test prog.children[1] isa Hole
        @test prog.children[2] isa Hole
    end
end

@testset "grow" begin
    # Grammar:
    #   rule 1: Int = 1          (terminal)
    #   rule 2: Int = 2          (terminal)
    #   rule 3: Int = Int + Int  (non-terminal, 2 Int children)
    g = @csgrammar begin
        Int = 1
        Int = 2
        Int = Int + Int
    end

    b = BUBank{RuleNode}()
    add!(b, :Int, 1, RuleNode(1))
    add!(b, :Int, 1, RuleNode(2))

    iter = TestSizeIter()
    ops  = findall(.!g.isterminal)

    @testset "level below first non-terminal" begin
        # node_cost=1, budget=level-1; for level=2, budget=1
        # compositions(1, 2) is empty → no programs
        @test isempty(collect(grow(iter, 2, g, b, ops)))
    end

    @testset "level 3: first non-terminal programs" begin
        # node_cost=1, budget=2; compositions(2,2) = [(1,1)]
        # product of two cost-1 Int children: 4 combinations
        result = Set((prog, t) for (prog, t) in grow(iter, 3, g, b, ops))
        expected = Set([
            (RuleNode(3, [RuleNode(1), RuleNode(1)]), :Int),
            (RuleNode(3, [RuleNode(1), RuleNode(2)]), :Int),
            (RuleNode(3, [RuleNode(2), RuleNode(1)]), :Int),
            (RuleNode(3, [RuleNode(2), RuleNode(2)]), :Int),
        ])
        @test result == expected
    end

    @testset "level 4: one cost-2 child" begin
        # Seed bank with cost-2 programs first
        add!(b, :Int, 2, RuleNode(3, [RuleNode(1), RuleNode(1)]))
        add!(b, :Int, 2, RuleNode(3, [RuleNode(1), RuleNode(2)]))

        # budget=3; compositions(3,2) = [(1,2), (2,1)]
        result = Set(prog for (prog, _) in grow(iter, 4, g, b, ops))

        # (1,2): cost-1 × cost-2
        @test RuleNode(3, [RuleNode(1), RuleNode(3, [RuleNode(1), RuleNode(1)])]) ∈ result
        @test RuleNode(3, [RuleNode(2), RuleNode(3, [RuleNode(1), RuleNode(2)])]) ∈ result
        # (2,1): cost-2 × cost-1
        @test RuleNode(3, [RuleNode(3, [RuleNode(1), RuleNode(1)]), RuleNode(1)]) ∈ result
        @test RuleNode(3, [RuleNode(3, [RuleNode(1), RuleNode(2)]), RuleNode(2)]) ∈ result
    end

    @testset "cost-based: node_cost from rule costs" begin
        # Same grammar but with costs: rule 1→2, rule 2→2, rule 3→1
        cost_iter = TestCostIter([2, 2, 1])
        bc   = BUBank{RuleNode}()
        add!(bc, :Int, 2, RuleNode(1))
        add!(bc, :Int, 2, RuleNode(2))

        # grow at level 5: node_cost(op=3)=1, budget=4
        # compositions(4,2) = [(1,3),(2,2),(3,1)] — but bank only has cost-2 entries
        # so only (2,2) applies
        result = Set(prog for (prog, _) in grow(cost_iter, 5, g, bc, ops))
        @test result == Set([
            RuleNode(3, [RuleNode(1), RuleNode(1)]),
            RuleNode(3, [RuleNode(1), RuleNode(2)]),
            RuleNode(3, [RuleNode(2), RuleNode(1)]),
            RuleNode(3, [RuleNode(2), RuleNode(2)]),
        ])
    end
end

@testset "compositions" begin
    # basic cases
    @test Set(collect(compositions(1, 1))) == Set([(1,)])
    @test Set(collect(compositions(3, 1))) == Set([(3,)])
    @test Set(collect(compositions(3, 2))) == Set([(1,2), (2,1)])
    @test Set(collect(compositions(4, 2))) == Set([(1,3), (2,2), (3,1)])
    @test Set(collect(compositions(3, 3))) == Set([(1,1,1)])

    # impossible: k parts each ≥ 1 require sum ≥ k
    @test isempty(collect(compositions(2, 3)))
    @test isempty(collect(compositions(0, 1)))

    # all returned tuples satisfy sum == n and every element >= 1
    for (n, k) in [(5, 2), (5, 3), (6, 4)]
        for t in compositions(n, k)
            @test sum(t) == n
            @test all(x -> x >= 1, t)
            @test length(t) == k
        end
    end

    # count matches binomial coefficient C(n-1, k-1)
    @test length(collect(compositions(5, 2))) == binomial(4, 1)
    @test length(collect(compositions(5, 3))) == binomial(4, 2)
    @test length(collect(compositions(6, 4))) == binomial(5, 3)
end

@testset "program_combinations" begin
    # Grammar (implicit):
    #   rule 1: Int  = 1          (terminal)
    #   rule 2: Int  = 2          (terminal)
    #   rule 3: Int  = Int + Int  (non-terminal, 2 children)
    #   rule 4: Bool = true       (terminal)

    # Cost-1 programs (leaves)
    leaf1    = RuleNode(1)
    leaf2    = RuleNode(2)
    leaf_true = RuleNode(4)

    # Cost-2 programs: Int+Int where both children are cost-1
    plus_1_1 = RuleNode(3, [RuleNode(1), RuleNode(1)])
    plus_1_2 = RuleNode(3, [RuleNode(1), RuleNode(2)])
    plus_2_1 = RuleNode(3, [RuleNode(2), RuleNode(1)])

    # Cost-3 programs: Int+Int where one child is cost-2
    plus_11_1 = RuleNode(3, [RuleNode(3, [RuleNode(1), RuleNode(1)]), RuleNode(1)])
    plus_1_11 = RuleNode(3, [RuleNode(1), RuleNode(3, [RuleNode(1), RuleNode(1)])])

    b = BUBank{RuleNode}()
    add!(b, :Int,  1, leaf1)
    add!(b, :Int,  1, leaf2)
    add!(b, :Int,  2, plus_1_1)
    add!(b, :Int,  2, plus_1_2)
    add!(b, :Int,  2, plus_2_1)
    add!(b, :Int,  3, plus_11_1)
    add!(b, :Int,  3, plus_1_11)
    add!(b, :Bool, 1, leaf_true)

    @testset "budget=2, two Int children" begin
        # only composition (1,1): {leaf1,leaf2} × {leaf1,leaf2}
        result = Set(collect(program_combinations(b, [:Int, :Int], 2)))
        @test result == Set([
            (leaf1, leaf1), (leaf1, leaf2),
            (leaf2, leaf1), (leaf2, leaf2),
        ])
    end

    @testset "budget=3, two Int children" begin
        # compositions (1,2) and (2,1)
        result = Set(collect(program_combinations(b, [:Int, :Int], 3)))
        @test result == Set([
            (leaf1, plus_1_1), (leaf1, plus_1_2), (leaf1, plus_2_1),
            (leaf2, plus_1_1), (leaf2, plus_1_2), (leaf2, plus_2_1),
            (plus_1_1, leaf1), (plus_1_1, leaf2),
            (plus_1_2, leaf1), (plus_1_2, leaf2),
            (plus_2_1, leaf1), (plus_2_1, leaf2),
        ])
    end

    @testset "budget=4, two Int children" begin
        # compositions (1,3), (2,2), (3,1)
        result = Set(collect(program_combinations(b, [:Int, :Int], 4)))
        expected = Set([
            # (1,3): leaf × cost-3
            (leaf1, plus_11_1), (leaf1, plus_1_11),
            (leaf2, plus_11_1), (leaf2, plus_1_11),
            # (2,2): cost-2 × cost-2
            (plus_1_1, plus_1_1), (plus_1_1, plus_1_2), (plus_1_1, plus_2_1),
            (plus_1_2, plus_1_1), (plus_1_2, plus_1_2), (plus_1_2, plus_2_1),
            (plus_2_1, plus_1_1), (plus_2_1, plus_1_2), (plus_2_1, plus_2_1),
            # (3,1): cost-3 × leaf
            (plus_11_1, leaf1), (plus_11_1, leaf2),
            (plus_1_11, leaf1), (plus_1_11, leaf2),
        ])
        @test result == expected
    end

    @testset "mixed types" begin
        # budget=2, [:Int, :Bool]: only (1,1); Bool has no cost-2 programs
        result = Set(collect(program_combinations(b, [:Int, :Bool], 2)))
        @test result == Set([(leaf1, leaf_true), (leaf2, leaf_true)])

        # budget=3, [:Int, :Bool]: (2,1) only — Bool has no cost-2 programs
        result = Set(collect(program_combinations(b, [:Int, :Bool], 3)))
        @test result == Set([
            (plus_1_1, leaf_true), (plus_1_2, leaf_true), (plus_2_1, leaf_true)
        ])
    end

    @testset "single child" begin
        result = Set(collect(program_combinations(b, [:Int], 2)))
        @test result == Set([(plus_1_1,), (plus_1_2,), (plus_2_1,)])
    end

    @testset "no programs at budget" begin
        @test isempty(collect(program_combinations(b, [:Int, :Int], 10)))
        # Bool has no cost ≥ 2, so any budget ≥ 3 with two Bool slots is empty
        @test isempty(collect(program_combinations(b, [:Bool, :Bool], 3)))
    end
end

@testset "BUBank" verbose = true begin

    @testset "add! and get_programs" begin
        b = BUBank{RuleNode}()
        p1, p2, p3 = RuleNode(1), RuleNode(2), RuleNode(3)

        add!(b, :Int, 1, p1)
        add!(b, :Int, 1, p2)
        add!(b, :Int, 2, p3)
        add!(b, :Bool, 1, RuleNode(4))

        @test get_programs(b, :Int, 1) == [p1, p2]
        @test get_programs(b, :Int, 2) == [p3]
        @test get_programs(b, :Int, 9) == RuleNode[]   # missing cost
        @test get_programs(b, :Foo, 1) == RuleNode[]   # missing type
    end

    @testset "get_costs" begin
        b = BUBank{RuleNode}()
        add!(b, :Int, 1, RuleNode(1))
        add!(b, :Int, 3, RuleNode(2))
        add!(b, :Int, 3, RuleNode(3))

        @test Set(get_costs(b, :Int)) == Set([1, 3])
        @test isempty(get_costs(b, :Foo))              # missing type
    end

    @testset "get_types" begin
        b = BUBank{RuleNode}()
        add!(b, :Int,  1, RuleNode(1))
        add!(b, :Bool, 1, RuleNode(2))

        @test Set(get_types(b)) == Set([:Int, :Bool])

        @test isempty(get_types(BUBank{RuleNode}()))   # empty bank
    end

    @testset "has_programs" begin
        b = BUBank{RuleNode}()
        add!(b, :Int, 1, RuleNode(1))
        add!(b, :Int, 2, RuleNode(2))

        @test  has_programs(b, :Int, 1)
        @test  has_programs(b, :Int, 2)
        @test !has_programs(b, :Int, 9)   # missing cost
        @test !has_programs(b, :Foo, 1)   # missing type
    end

end

@testset "CostBUSIterator" verbose = true begin
    # Grammar:
    #   rule 1: Int = 1          (terminal,     cost 2)
    #   rule 2: Int = 2          (terminal,     cost 2)
    #   rule 3: Int = Int + Int  (non-terminal, cost 1)
    #
    # Program costs (cost = sum of rule costs over all nodes):
    #   cost 2: RuleNode(1), RuleNode(2)
    #   cost 5: RuleNode(3, [RuleNode(1), RuleNode(2)]), etc.  (1 + 2 + 2)
    g = @csgrammar begin
        Int = 1
        Int = 2
        Int = Int + Int
    end
    costs = [2, 2, 1]  # rule 1→2, rule 2→2, rule 3→1

    @testset "terminals only (max_cost = 2)" begin
        iter = CostBUSIterator(g, :Int, 2, costs)
        result = collect(iter)
        @test Set(result) == Set([RuleNode(1), RuleNode(2)])
    end

    @testset "enumeration order: costs are non-decreasing" begin
        iter = CostBUSIterator(g, :Int, 6, costs)
        result = collect(iter)

        prog_cost(p) = costs[p.ind] + sum(prog_cost(c) for c in p.children; init=0)
        @test issorted(prog_cost.(result))
    end

    @testset "completeness: all cost-5 programs present" begin
        iter = CostBUSIterator(g, :Int, 5, costs)
        result = Set(collect(iter))

        # cost 5 = 1 (op) + 2 (child1) + 2 (child2)
        expected_cost5 = Set([
            RuleNode(3, [RuleNode(1), RuleNode(1)]),
            RuleNode(3, [RuleNode(1), RuleNode(2)]),
            RuleNode(3, [RuleNode(2), RuleNode(1)]),
            RuleNode(3, [RuleNode(2), RuleNode(2)]),
        ])
        @test expected_cost5 ⊆ result
        @test RuleNode(1) ∈ result
        @test RuleNode(2) ∈ result
    end

    @testset "max_cost respected: no program exceeds max_cost" begin
        max_c = 5
        iter = CostBUSIterator(g, :Int, max_c, costs)
        prog_cost(p) = costs[p.ind] + sum(prog_cost(c) for c in p.children; init=0)
        for prog in iter
            @test prog_cost(prog) <= max_c
        end
    end

    @testset "observational equivalence" begin
        # eval_fn: evaluate Int expression on a single input (x=3 irrelevant here,
        # grammar has no variables). Constant programs: 1→1, 2→2, 1+1→2, 1+2→3, etc.
        eval_fn = function(prog::RuleNode)
            function ev(p)
                p.ind == 1 && return 1
                p.ind == 2 && return 2
                return ev(p.children[1]) + ev(p.children[2])
            end
            [ev(prog)]
        end

        iter = CostBUSIterator(g, :Int, 5, costs, eval_fn)
        result = collect(iter)

        # RuleNode(2) evaluates to 2; RuleNode(3,[RuleNode(1),RuleNode(1)])
        # also evaluates to 2 → should be pruned.
        vals = [eval_fn(p)[1] for p in result]
        # No duplicate output values (OE removes them)
        @test length(vals) == length(unique(vals))

        # The values 1 and 2 (from terminals) must be present
        @test 1 ∈ vals
        @test 2 ∈ vals
    end

    @testset "observational equivalence with input-dependent programs" begin
        # Grammar:
        #   rule 1: Int = x          (terminal, cost 1)
        #   rule 2: Int = 0          (terminal, cost 1)
        #   rule 3: Int = Int + Int  (non-terminal, cost 1)
        #
        # Evaluated on inputs x ∈ [1, 2, 3]:
        #   x     → [1, 2, 3]
        #   0     → [0, 0, 0]
        #   x + x → [2, 4, 6]   (genuinely new)
        #   x + 0 → [1, 2, 3]   (OE with x)
        #   0 + x → [1, 2, 3]   (OE with x)
        #   0 + 0 → [0, 0, 0]   (OE with 0)
        g_oe = @csgrammar begin
            Int = x
            Int = 0
            Int = Int + Int
        end
        costs_oe = [1, 1, 1]
        inputs = [1, 2, 3]

        eval_fn = function(prog::RuleNode)
            function ev(p, x)
                p.ind == 1 && return x
                p.ind == 2 && return 0
                return ev(p.children[1], x) + ev(p.children[2], x)
            end
            [ev(prog, x) for x in inputs]
        end

        # Without OE: 2 terminals + 4 cost-3 composites = 6 programs
        result_no_oe = collect(CostBUSIterator(g_oe, :Int, 3, costs_oe, nothing))
        @test length(result_no_oe) == 6

        # With OE: only x, 0, and x+x survive
        result_oe = collect(CostBUSIterator(g_oe, :Int, 3, costs_oe, eval_fn))
        @test length(result_oe) == 3
        sigs = Set([eval_fn(p) for p in result_oe])
        @test [1, 2, 3] ∈ sigs   # x
        @test [0, 0, 0] ∈ sigs   # 0
        @test [2, 4, 6] ∈ sigs   # x + x
    end

    @testset "start_symbol filtering" begin
        # Grammar with two types; iterator should only yield :Bool programs
        g2 = @csgrammar begin
            Int  = 1
            Int  = 2
            Bool = true
            Bool = Int == Int
        end
        costs2 = [1, 1, 1, 1]
        iter = CostBUSIterator(g2, :Bool, 3, costs2)
        result = collect(iter)
        # All yielded programs must have return type :Bool
        @test all(p -> g2.types[p.ind] == :Bool, result)
        # The terminal Bool=true must be present
        @test RuleNode(3) ∈ result
    end

    @testset "matches DFSIterator count (all costs = 1, max_cost = max_size = 5)" begin
        # With all rule costs = 1, cost(program) = number of nodes = size,
        # so CostBUSIterator(max_cost=5) should enumerate the same number of
        # programs as DFSIterator(max_size=5).
        g_cmp = @csgrammar begin
            Int = 1
            Int = 2
            Int = Int + Int
        end
        unit_costs = ones(Int, length(g_cmp.rules))

        bus_count = length(collect(CostBUSIterator(g_cmp, :Int, 5, unit_costs)))
        dfs_count = length([freeze_state(p) for p in DFSIterator(g_cmp, :Int; max_size=5)])

        @test bus_count == dfs_count
    end

    # Helper: compare CostBUSIterator (unit costs) against DFSIterator for a
    # given grammar, start symbol, and range of max sizes.
    function compare_bus_dfs(g, start; sizes=2:10)
        unit_costs = ones(Int, length(g.rules))
        for max_size in sizes
            bus_count = length(collect(CostBUSIterator(g, start, max_size, unit_costs)))
            dfs_count = length([freeze_state(p) for p in DFSIterator(g, start; max_size=max_size)])
            @testset "max_size=$max_size" begin
                @test bus_count == dfs_count
            end
        end
    end

    @testset "arity-1 grammar (unary operator)" begin
        # Int = 1 | 2 | 3 + Int
        g = @csgrammar begin
            Int = 1
            Int = 2
            Int = 3 + Int
        end
        compare_bus_dfs(g, :Int)
    end

    @testset "arity-3 grammar (ternary operator)" begin
        # Int = 1 | Int + Int | f(Int, Int, Int)
        g = @csgrammar begin
            Int = 1
            Int = Int + Int
            Int = f(Int, Int, Int)
        end
        compare_bus_dfs(g, :Int; sizes=2:4)
    end

    @testset "multiple types (Int, Char, String)" begin
        # Replicates the 'multiple types' grammar from test_bottom_up.jl.
        # Only :Int programs are yielded; :Char and :String programs are used
        # as intermediate values (via length(String) and Char * Char).
        g = @csgrammar begin
            Int    = 1
            Int    = 2
            Int    = Int + Int
            Char   = 'a'
            Char   = 'b'
            String = Char * Char
            Int    = length(String)
            Int    = Int * Int
        end
        compare_bus_dfs(g, :Int; sizes=2:4)
    end

    @testset "OE: grammar with addition and subtraction" begin
        # Grammar (all costs = 1):
        #   rule 1: Int = x          (terminal)
        #   rule 2: Int = 0          (terminal)
        #   rule 3: Int = Int + Int  (non-terminal)
        #   rule 4: Int = Int - Int  (non-terminal)
        #
        # Evaluated on inputs x ∈ [1, 2, 4]:
        # Many equivalences arise, e.g.:
        #   x + 0 ≡ x,  0 + x ≡ x,  x - 0 ≡ x
        #   0 - 0 ≡ 0,  x - x ≡ 0
        g_arith = @csgrammar begin
            Int = x
            Int = 0
            Int = Int + Int
            Int = Int - Int
        end
        costs_arith = [1, 1, 1, 1]
        inputs = [1, 2, 4]

        eval_fn = function(prog::RuleNode)
            function ev(p, x)
                p.ind == 1 && return x
                p.ind == 2 && return 0
                p.ind == 3 && return ev(p.children[1], x) + ev(p.children[2], x)
                              return ev(p.children[1], x) - ev(p.children[2], x)
            end
            [ev(prog, x) for x in inputs]
        end

        result_no_oe = collect(CostBUSIterator(g_arith, :Int, 3, costs_arith, nothing))
        result_oe    = collect(CostBUSIterator(g_arith, :Int, 3, costs_arith, eval_fn))

        # OE must prune at least some programs
        @test length(result_oe) < length(result_no_oe)

        # No two surviving programs share an output signature
        sigs = [eval_fn(p) for p in result_oe]
        @test length(sigs) == length(unique(sigs))
    end

    @testset "OE: Bool programs via Int == Int" begin
        # Grammar (all costs = 1):
        #   rule 1: Int  = x
        #   rule 2: Int  = 0
        #   rule 3: Int  = Int + Int
        #   rule 4: Bool = Int == Int
        #
        # Evaluated on inputs x ∈ [0, 1, 2].
        # Many Int == Int expressions evaluate to false (e.g. x == 0, x+x == 0),
        # so OE prunes heavily among :Bool programs.
        g_bool = @csgrammar begin
            Int  = x
            Int  = 0
            Int  = Int + Int
            Bool = Int == Int
        end
        costs_bool = [1, 1, 1, 1]
        inputs = [0, 1, 2]

        eval_fn = function(prog::RuleNode)
            function ev(p, x)
                p.ind == 1 && return x
                p.ind == 2 && return 0
                p.ind == 3 && return ev(p.children[1], x) + ev(p.children[2], x)
                              return ev(p.children[1], x) == ev(p.children[2], x)
            end
            [ev(prog, x) for x in inputs]
        end

        result_no_oe = collect(CostBUSIterator(g_bool, :Bool, 4, costs_bool, nothing))
        result_oe    = collect(CostBUSIterator(g_bool, :Bool, 4, costs_bool, eval_fn))

        # OE must prune at least some programs
        @test length(result_oe) < length(result_no_oe)

        # No two surviving programs share an output signature
        sigs = [eval_fn(p) for p in result_oe]
        @test length(sigs) == length(unique(sigs))
    end

    @testset "OE: two-variable grammar" begin
        # Grammar (all costs = 1):
        #   rule 1: Int = x
        #   rule 2: Int = y
        #   rule 3: Int = 0
        #   rule 4: Int = Int + Int
        #
        # Evaluated on pairs (x, y) ∈ [(0,1), (1,2), (3,0)].
        # Equivalences include: x+0 ≡ x, y+0 ≡ y, 0+x ≡ x, etc.
        g_xy = @csgrammar begin
            Int = x
            Int = y
            Int = 0
            Int = Int + Int
        end
        costs_xy = [1, 1, 1, 1]
        inputs = [(0,1), (1,2), (3,0)]

        eval_fn = function(prog::RuleNode)
            function ev(p, x, y)
                p.ind == 1 && return x
                p.ind == 2 && return y
                p.ind == 3 && return 0
                              return ev(p.children[1], x, y) + ev(p.children[2], x, y)
            end
            [ev(prog, x, y) for (x, y) in inputs]
        end

        result_no_oe = collect(CostBUSIterator(g_xy, :Int, 3, costs_xy, nothing))
        result_oe    = collect(CostBUSIterator(g_xy, :Int, 3, costs_xy, eval_fn))

        # OE must prune at least some programs
        @test length(result_oe) < length(result_no_oe)

        # No two surviving programs share an output signature
        sigs = [eval_fn(p) for p in result_oe]
        @test length(sigs) == length(unique(sigs))
    end

    @testset "type_cost_bounds: per-type cap respected" begin
        # Grammar (all costs = 1):
        #   rule 1: Int = 1          (terminal)
        #   rule 2: Int = 2          (terminal)
        #   rule 3: Int = Int + Int  (non-terminal)
        #
        # Bounding :Int to max cost 1 means only the two terminals enter the
        # bank.  The non-terminal at cost 3 (1 op + 1 + 1) is never added, so
        # the iterator yields exactly the two terminals regardless of max_cost.
        g = @csgrammar begin
            Int = 1
            Int = 2
            Int = Int + Int
        end
        unit_costs = ones(Int, length(g.rules))
        bounds = Dict(:Int => 1)

        iter_bounded   = CostBUSIterator(g, :Int, 10, unit_costs, nothing, Dict{Symbol,Int}(bounds))
        iter_unbounded = CostBUSIterator(g, :Int, 10, unit_costs)

        result_bounded = collect(iter_bounded)
        @test Set(result_bounded) == Set([RuleNode(1), RuleNode(2)])
        @test length(collect(iter_unbounded)) > length(result_bounded)
    end

    @testset "type_cost_bounds: bounds on child type, not start_symbol" begin
        # Grammar (all costs = 1):
        #   rule 1: Int  = 1
        #   rule 2: Int  = 2
        #   rule 3: Bool = true
        #   rule 4: Bool = Int == Int
        #
        # Bounding :Int to max cost 1 still allows Bool = Int == Int to be
        # formed at cost 3 (using cost-1 Int terminals as children).
        g2 = @csgrammar begin
            Int  = 1
            Int  = 2
            Bool = true
            Bool = Int == Int
        end
        unit_costs2 = ones(Int, length(g2.rules))
        bounds2 = Dict(:Int => 1)

        iter = CostBUSIterator(g2, :Bool, 5, unit_costs2, nothing, Dict{Symbol,Int}(bounds2))
        result = collect(iter)

        # The terminal Bool=true must be present
        @test RuleNode(3) ∈ result
        # Bool = (1 == 1), (1 == 2), (2 == 1), (2 == 2) must all be present
        @test RuleNode(4, [RuleNode(1), RuleNode(1)]) ∈ result
        @test RuleNode(4, [RuleNode(1), RuleNode(2)]) ∈ result
        @test RuleNode(4, [RuleNode(2), RuleNode(1)]) ∈ result
        @test RuleNode(4, [RuleNode(2), RuleNode(2)]) ∈ result
        # No Int programs should be yielded (start_symbol is :Bool)
        @test all(p -> g2.types[p.ind] == :Bool, result)
    end

    @testset "constraint checking: Forbidden pattern not yielded" begin
        # Grammar (all costs = 1):
        #   rule 1: Int = 1
        #   rule 2: Int = 2
        #   rule 3: Int = Int + Int
        #
        # Forbidden constraint: Int + Int where both children are the same variable,
        # i.e. RuleNode(3, [VarNode(:a), VarNode(:a)]) — forbids e.g. 1+1, 2+2.
        g = @csgrammar begin
            Int = 1
            Int = 2
            Int = Int + Int
        end
        forbidden = Forbidden(RuleNode(3, [VarNode(:a), VarNode(:a)]))
        HerbConstraints.addconstraint!(g, forbidden)
        costs = ones(Int, length(g.rules))

        result = collect(CostBUSIterator(g, :Int, 5, costs))

        # No yielded program should match the forbidden pattern
        @test all(HerbConstraints.check_tree(forbidden, p) for p in result)

        # The unconstrained iterator yields more programs
        g_unconstrained = @csgrammar begin
            Int = 1
            Int = 2
            Int = Int + Int
        end
        result_unconstrained = collect(CostBUSIterator(g_unconstrained, :Int, 5, costs))
        @test length(result) < length(result_unconstrained)
    end
end



# julia --project=. -e '
#   using HerbCore, HerbGrammar, HerbSearch

#   g = @csgrammar begin
#       Int = 1
#       Int = 2
#       Int = 3
#       Int = Int + Int
#       Int = Int * Int
#   end
#   costs = ones(Int, length(g.rules))
#   n = 0

#   t = @elapsed n = sum(1 for _ in CostBUSIterator(g, :Int, 11, costs))

#   println("Enumerated $n programs in $(round(t; digits=2))s")
#   '
#
#
#
# julia --project=. -e '
  # using HerbCore, HerbGrammar, HerbSearch

  # g = @csgrammar begin
  #     Int = 1
  #     Int = 2
  #     Int = 3
  #     Int = Int + Int
  #     Int = Int * Int
  # end
  # costs = ones(Int, length(g.rules))
  # n = 0

  # eval_fn = function(prog::RuleNode)
  #     function ev(p)
  #         p.ind == 1 && return 1
  #         p.ind == 2 && return 2
  #         p.ind == 3 && return 3
  #         p.ind == 4 && return ev(p.children[1]) + ev(p.children[2])
  #                       return ev(p.children[1]) * ev(p.children[2])
  #     end
  #     [ev(prog)]
  # end

  # t = @elapsed n = sum(1 for _ in CostBUSIterator(g, :Int, 11, costs, eval_fn))

  # println("Enumerated $n programs in $(round(t; digits=2))s")
  # '




  # julia --project=. -e '
  #   using HerbCore, HerbGrammar, HerbSearch

  #   g = @csgrammar begin
  #       Int = x
  #       Int = 0
  #       Int = 1
  #       Int = Int + Int
  #       Int = Int * Int
  #   end
  #   costs = ones(Int, length(g.rules))

  #   inputs = [1, 2, 3, 5, 7]

  #   eval_fn = function(prog::RuleNode)
  #       function ev(p, x)
  #           p.ind == 1 && return x
  #           p.ind == 2 && return 0
  #           p.ind == 3 && return 1
  #           p.ind == 4 && return ev(p.children[1], x) + ev(p.children[2], x)
  #                         return ev(p.children[1], x) * ev(p.children[2], x)
  #       end
  #       [ev(prog, x) for x in inputs]
  #   end

  #   t = @elapsed n = sum(1 for _ in CostBUSIterator(g, :Int, 11, costs, eval_fn))

  #   println("Enumerated $n programs in $(round(t; digits=2))s")
  #   '
  #
  #
  #

  # julia --project=. -e '
  #   using HerbCore, HerbGrammar, HerbSearch

  #   g = @csgrammar begin
  #       Int = x
  #       Int = 0
  #       Int = 1
  #       Int = Int + Int
  #       Int = Int * Int
  #   end
  #   costs = ones(Int, length(g.rules))

  #   inputs = [1, 2, 3, 5, 7]

  #   t = @elapsed n = sum(1 for _ in CostBUSIterator(g, :Int, 11, costs))

  #   println("Enumerated $n programs in $(round(t; digits=2))s")
  #   '
