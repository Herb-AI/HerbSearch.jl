using HerbCore, HerbGrammar, HerbConstraints, HerbSearch
using HerbSearch: bfs_priority, BFSPriority, TopDownState, requeue_fast_path, priority_function,
    AbstractBFSIterator, AbstractUniformIterator
using Test

# The order of the top-down iterators must not depend on the constraints: with constraints, an iterator gives the
# programs it gives without them, in the same order, minus the ones the constraints remove.

"All programs of `iter`, frozen, in order."
function _programs(iter)
    programs = RuleNode[]
    for p ∈ iter
        push!(programs, freeze_state(p))
    end
    return programs
end

"`grammar` with `constraints` added (the grammar is copied)."
function _with_constraints(grammar, constraints)
    g = deepcopy(grammar)
    for c ∈ constraints
        addconstraint!(g, c)
    end
    return g
end

"""
The sequence of `Iter` with `constraints` must equal the sequence without them, filtered by `check_tree` of every
constraint.
"""
function _test_constrained_is_filtered(Iter, grammar, start, constraints; kwargs...)
    unconstrained = _programs(Iter(grammar, start; kwargs...))
    constrained = _programs(Iter(_with_constraints(grammar, constraints), start; kwargs...))
    expected = filter(p -> all(c -> check_tree(c, p), constraints), unconstrained)
    @test length(constrained) == length(expected)
    @test constrained == expected
    return length(unconstrained), length(constrained)
end

"The shape of a complete program: its pre-order shape ids."
_shape(grammar, program) = bfs_priority(grammar, program).ids

# A BFS iterator that checks that every new state's priority exceeds its parent's
@programiterator KeyCheckBFSIterator(violations::Vector{Any} = Any[]) <: AbstractBFSIterator

function HerbSearch.priority_function(
    iter::KeyCheckBFSIterator,
    g::AbstractGrammar,
    tree::AbstractRuleNode,
    parent_value,
    isrequeued::Bool
)
    isrequeued && return parent_value
    p = bfs_priority(g, tree)
    if parent_value isa BFSPriority && !isless(parent_value, p)
        push!(iter.violations, (parent_value, p, deepcopy(tree)))
    end
    return p
end
HerbSearch.priority_type(::KeyCheckBFSIterator) = BFSPriority

# The old BFS priority (branching steps, `parent_value + 1`; a requeued shape keeps `parent_value`): requeued shapes
# tie with other entries, so their order is defined by the FIFO tie-break only. With and without the fast path.
@programiterator OldBFSIterator() <: TopDownIterator
@programiterator OldBFSNoFastPathIterator() <: TopDownIterator
HerbSearch.requeue_fast_path(::OldBFSNoFastPathIterator) = false

# Several shapes per type
grammar_shapes = @csgrammar begin
    Int = 1 | 2 | x                 # 1, 2, 3
    Int = Int + Int                 # 4
    Int = Int * Int                 # 5
    Int = -Int                      # 6
    Int = ite(Bool, Int, Int)       # 7
    Bool = Int < Int                # 8
    Bool = !Bool                    # 9
    Bool = true                     # 10
end
constraints_shapes = [
    Forbidden(RuleNode(6, [RuleNode(6, [VarNode(:a)])])),              # no --a
    Forbidden(RuleNode(4, [RuleNode(1), VarNode(:a)])),                # removes the smallest rule of a shape
    Ordered(RuleNode(4, [VarNode(:a), VarNode(:b)]), [:a, :b]),
    Contains(3),
    Unique(1),
    ForbiddenSequence([7, 9]),
]

# Types with a single shape (B, C): their holes are filled by propagation, without a branching step
grammar_single_shape = @csgrammar begin
    S = f(A, A)                     # 1
    S = g(B)                        # 2
    A = 1                           # 3
    A = h(A)                        # 4
    A = m(A, B)                     # 5
    B = k(C, C)                     # 6
    C = 0 | 1                       # 7, 8
end
constraints_single_shape = [
    Forbidden(RuleNode(4, [RuleNode(3)])),                             # no h(1)
    Forbidden(RuleNode(6, [RuleNode(7), VarNode(:a)])),
    Ordered(RuleNode(1, [VarNode(:a), VarNode(:b)]), [:a, :b]),
    Contains(8),
    Unique(5),
    ForbiddenSequence([1, 4, 4]),
]

# HerbSearch #148
grammar_148 = @csgrammar begin
    StartSymbol = ExprArr | ExprNum
    ExprNum = |(1:3)
    ExprNum = first(ExprArr)
    ExprNum = sum(ExprArr)
    ExprArr = a
    ExprArr = first(ExprArr, ExprNum)
    ExprArr = sort(ExprArr)
    ExprArr = reverse(ExprArr)
end
forbid_148 = Forbidden(RuleNode(1, [DomainRuleNode(grammar_148, [6, 10, 11],
    [DomainRuleNode(grammar_148, [9], [RuleNode(8, []), RuleNode(6, [RuleNode(8)])])])]))
forbid2_148 = Forbidden(RuleNode(1, [DomainRuleNode(grammar_148, [10, 11], [RuleNode(8, [])])]))
forbid3_148 = Forbidden(RuleNode(2, [DomainRuleNode(grammar_148, [6, 10, 11], [DomainRuleNode(grammar_148, [6, 10, 11],
    [DomainRuleNode(grammar_148, [9], [DomainRuleNode(grammar_148, [6, 10, 11], [RuleNode(8, [])]),
        DomainRuleNode(grammar_148, [3, 4, 5])])])])]))
solution_148 = RuleNode(2, [RuleNode(7, [RuleNode(9, [RuleNode(11, [RuleNode(10, [RuleNode(8)])]), RuleNode(4)])])])

"The number of programs `iter` gives up to and including `target`, or `nothing` if it doesn't give it."
function _programs_until(iter, target)
    for (i, p) ∈ enumerate(iter)
        freeze_state(p) == target && return i
    end
    return nothing
end

@testset verbose = true "Top-down order doesn't depend on the constraints" begin
    @testset "HerbSearch #167: BFS gives the earlier rules first" begin
        g = @csgrammar begin
            Const = 0
            Const = 1
            Entity = A
            Entity = B
            Entity = C
            Expr = Const
            Expr = Entity
            Model = [(A, Expr), (B, Expr), (C, Expr)]
        end
        @test freeze_state(first(BFSIterator(g, :Model; max_depth=3))) ==
              RuleNode(8, [RuleNode(6, [RuleNode(1)]), RuleNode(6, [RuleNode(1)]), RuleNode(6, [RuleNode(1)])])
    end

    @testset "Constrained = unconstrained, filtered ($(nameof(Iter)))" for Iter ∈ (BFSIterator, DFSIterator)
        @testset "several shapes per type: $(c)" for c ∈ [[c] for c ∈ constraints_shapes]
            _test_constrained_is_filtered(Iter, grammar_shapes, :Int, c; max_size=6, max_depth=4)
        end
        @testset "several shapes per type: all constraints" begin
            _test_constrained_is_filtered(Iter, grammar_shapes, :Int, constraints_shapes; max_size=6, max_depth=4)
        end
        @testset "single-shape types: $(c)" for c ∈ [[c] for c ∈ constraints_single_shape]
            _test_constrained_is_filtered(Iter, grammar_single_shape, :S, c; max_size=8, max_depth=5)
        end
        @testset "single-shape types: all constraints" begin
            _test_constrained_is_filtered(Iter, grammar_single_shape, :S, constraints_single_shape; max_size=8, max_depth=5)
        end
        @testset "HerbSearch #148: $(name)" for (name, c) ∈ [
            ("forbid", [forbid_148]), ("forbid2", [forbid2_148]), ("forbid3", [forbid3_148]),
            ("all", [forbid_148, forbid2_148, forbid3_148])]
            _test_constrained_is_filtered(Iter, grammar_148, :StartSymbol, c; max_size=7, max_depth=5)
        end
    end

    @testset "HerbSearch #148: a constraint that keeps the solution doesn't delay it" begin
        unconstrained = _programs_until(BFSIterator(grammar_148, :StartSymbol; max_depth=6), solution_148)
        @test !isnothing(unconstrained)
        for c ∈ (forbid_148, forbid2_148, forbid3_148)
            @test check_tree(c, solution_148)
            constrained = _programs_until(BFSIterator(_with_constraints(grammar_148, [c]), :StartSymbol; max_depth=6), solution_148)
            @test !isnothing(constrained) && constrained <= unconstrained
        end
    end

    @testset "DFS: removing a shape's smallest rule doesn't reorder the shapes" begin
        g = @csgrammar begin
            S = a(T)        # 1   shape {1, 3}
            S = b(T, T)     # 2   shape {2}
            S = e(T)        # 3
            T = 1 | 2       # 4, 5
        end
        unconstrained = _programs(DFSIterator(g, :S))
        @test [get_rule(p) for p ∈ unconstrained] == [1, 1, 3, 3, 2, 2, 2, 2]
        forbid_a = Forbidden(RuleNode(1, [VarNode(:x)]))
        constrained = _programs(DFSIterator(_with_constraints(g, [forbid_a]), :S))
        @test constrained == filter(p -> get_rule(p) != 1, unconstrained)
    end

    @testset "BFS gives non-decreasing sizes" begin
        # The size-5 shape g(k(0,0,0)) needs one branching step and the size-3 shape f(1,1) needs three: the old
        # priority (branching steps) gave g(k(0,0,0)) first.
        g = @csgrammar begin
            S = f(A, A)
            S = g(B)
            A = 1
            A = h(A)
            B = k(C, C, C)
            C = 0
        end
        for (grammar, start, kwargs) ∈ [
            (g, :S, (; max_depth=4)),
            (grammar_shapes, :Int, (; max_size=6)),
            (grammar_single_shape, :S, (; max_size=8)),
            (_with_constraints(grammar_shapes, constraints_shapes), :Int, (; max_size=6)),
        ]
            sizes = length.(_programs(BFSIterator(grammar, start; kwargs...)))
            @test !isempty(sizes)
            @test issorted(sizes)
        end
        @test freeze_state(first(BFSIterator(g, :S; max_depth=4))) == RuleNode(1, [RuleNode(3), RuleNode(3)])
    end

    @testset "BFS: shapes come out one at a time, in increasing priority" begin
        programs = _programs(BFSIterator(grammar_shapes, :Int; max_size=6))
        shapes = [_shape(grammar_shapes, p) for p ∈ programs]
        runs = [shapes[1]]
        for s ∈ shapes[2:end]
            s == runs[end] || push!(runs, s)
        end
        @test allunique(runs)
        @test issorted(BFSPriority.(runs))
    end

    @testset "BFS priority" begin
        g = grammar_shapes
        @test [shape_id(g, r) for r ∈ 1:10] == [1, 1, 1, 4, 4, 6, 7, 8, 9, 10]
        hole_int = Hole(get_domain(g, :Int))
        hole_bool = Hole(get_domain(g, :Bool))
        plus = RuleNode(4, [hole_int, hole_int])
        times = UniformHole(BitVector([0, 0, 0, 1, 1, 0, 0, 0, 0, 0]), [hole_int, RuleNode(2)])
        @test bfs_priority(g, hole_int).ids == [0]
        @test bfs_priority(g, plus).ids == [4, 0, 0]
        @test bfs_priority(g, times).ids == [4, 0, 1]
        # parent < child: filling a hole adds nodes, or replaces a 0 at the same size
        @test isless(bfs_priority(g, hole_int), bfs_priority(g, plus))
        @test isless(bfs_priority(g, plus), bfs_priority(g, times))
        @test isless(bfs_priority(g, RuleNode(4, [RuleNode(1), hole_int])),
            bfs_priority(g, RuleNode(7, [hole_bool, hole_int, hole_int])))
        # size first
        @test isless(bfs_priority(g, RuleNode(7, [hole_bool, hole_int, hole_int])),
            bfs_priority(g, RuleNode(6, [RuleNode(6, [RuleNode(6, [RuleNode(6, [hole_int])])])])))
        # the shape id doesn't depend on the domain: rules 4 and 5 are one shape
        @test bfs_priority(g, UniformHole(BitVector([0, 0, 0, 0, 1, 0, 0, 0, 0, 0]), [hole_int, hole_int])) ==
              bfs_priority(g, plus)

        @testset "a new state's priority exceeds its parent's ($(name))" for (name, grammar, start, kwargs) ∈ [
            ("several shapes", grammar_shapes, :Int, (; max_size=6)),
            ("several shapes, constrained", _with_constraints(grammar_shapes, constraints_shapes), :Int, (; max_size=6)),
            ("single-shape types, constrained", _with_constraints(grammar_single_shape, constraints_single_shape), :S, (; max_size=8)),
            ("#148", grammar_148, :StartSymbol, (; max_depth=5)),
        ]
            iter = KeyCheckBFSIterator(grammar, start; kwargs...)
            @test _programs(iter) == _programs(BFSIterator(grammar, start; kwargs...))
            @test isempty(iter.violations)
        end
    end

    @testset "DFS: the programs of a shape are consecutive" begin
        for (grammar, start, kwargs) ∈ [
            (grammar_shapes, :Int, (; max_size=6, max_depth=4)),
            (grammar_single_shape, :S, (; max_size=8, max_depth=5)),
            (_with_constraints(grammar_shapes, constraints_shapes), :Int, (; max_size=6, max_depth=4)),
        ]
            shapes = [_shape(grammar, p) for p ∈ _programs(DFSIterator(grammar, start; kwargs...))]
            runs = [shapes[1]]
            for s ∈ shapes[2:end]
                s == runs[end] || push!(runs, s)
            end
            @test allunique(runs)
        end
    end

    @testset "Requeue fast path" begin
        @testset "doesn't change the order ($(name))" for (name, grammar, start, kwargs) ∈ [
            ("several shapes", grammar_shapes, :Int, (; max_size=6)),
            ("single-shape types", grammar_single_shape, :S, (; max_size=8)),
            ("#148, constrained", _with_constraints(grammar_148, [forbid_148, forbid2_148]), :StartSymbol, (; max_depth=5)),
        ]
            @test requeue_fast_path(OldBFSIterator(grammar, start; kwargs...))
            @test !requeue_fast_path(OldBFSNoFastPathIterator(grammar, start; kwargs...))
            with_fast_path = _programs(OldBFSIterator(grammar, start; kwargs...))
            @test with_fast_path == _programs(OldBFSNoFastPathIterator(grammar, start; kwargs...))
            # the old priority gives the same programs as BFSIterator, in another order
            @test sort(with_fast_path, by=string) == sort(_programs(BFSIterator(grammar, start; kwargs...)), by=string)
        end

        @testset "is always taken by $(nameof(Iter))" for Iter ∈ (BFSIterator, DFSIterator)
            for (grammar, start) ∈ [(grammar_shapes, :Int), (_with_constraints(grammar_shapes, constraints_shapes), :Int)]
                iter = Iter(grammar, start; max_size=6, max_depth=4)
                next = iterate(iter)
                n = 0
                kept_out = 0
                pushed_back = 0
                @test next[2] isa TopDownState
                while !isnothing(next)
                    (_, st) = next
                    n += 1
                    # the shape of the program just returned is kept out of the queue...
                    kept_out += !isnothing(st.current)
                    # ...and no shape is ever pushed back
                    pushed_back += any(item isa AbstractUniformIterator for item ∈ keys(st.pq))
                    next = iterate(iter, st)
                end
                @test n > 0
                @test kept_out == n
                @test pushed_back == 0
            end
        end
    end
end
