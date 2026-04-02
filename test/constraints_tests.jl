@testitem "Constraints" begin
    using Random: randperm
    using HerbCore, HerbGrammar, HerbConstraints
    using HerbSearch: BFSASPIterator, DFSASPIterator
    include("test_helpers.jl")

    const ITERATORS = [BFSASPIterator, DFSASPIterator, BFSIterator, DFSIterator]
    function new_grammar()
        grammar = @csgrammar begin
            Int = 1
            Int = x
            Int = -Int
            Int = Int + Int
            Int = Int * Int
        end
        clearconstraints!(grammar)
        return grammar
    end

    contains_subtree = ContainsSubtree(RuleNode(4, [
        RuleNode(1),
        RuleNode(1)
    ]))

    contains_subtree2 = ContainsSubtree(RuleNode(4, [
        RuleNode(4, [
            VarNode(:a),
            RuleNode(2)
        ]),
        VarNode(:a)
    ]))

    contains = Contains(2)

    forbidden_sequence = ForbiddenSequence([4, 5])

    forbidden_sequence2 = ForbiddenSequence([4, 5], ignore_if=[3])

    forbidden_sequence3 = ForbiddenSequence([4, 1], ignore_if=[5])

    forbidden = Forbidden(RuleNode(3, [RuleNode(3, [VarNode(:a)])]))

    forbidden2 = Forbidden(RuleNode(4, [
        VarNode(:a),
        VarNode(:a)
    ]))

    ordered = Ordered(RuleNode(5, [
            VarNode(:a),
            VarNode(:b)
        ]), [:a, :b])

    unique = Unique(2)

    const ALL_CONSTRAINTS = [
        ("ContainsSubtree", contains_subtree),
        ("ContainsSubtree2", contains_subtree2),
        ("Contains", contains),
        ("ForbiddenSequence", forbidden_sequence),
        ("ForbiddenSequence2", forbidden_sequence2),
        ("ForbiddenSequence3", forbidden_sequence3),
        ("Forbidden", forbidden),
        ("Forbidden2", forbidden2),
        ("Ordered", ordered),
        ("Unique", unique)
    ]

    @testset "fix_point_running related bug" begin
        # post contains_subtree2
        # propagate contains_subtree2
        #     schedule forbidden2
        # propagate forbidden2

        grammar = new_grammar()
        addconstraint!(grammar, contains_subtree)
        addconstraint!(grammar, contains_subtree2)
        addconstraint!(grammar, forbidden2)

        partial_program = UniformHole(BitVector((0, 0, 0, 1, 1)), [
            UniformHole(BitVector((0, 0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0, 0)), [])
            ]),
            UniformHole(
                BitVector((0, 0, 0, 1, 1)),
                [
                    UniformHole(BitVector((0, 0, 0, 1, 1)), [
                        UniformHole(BitVector((1, 1, 0, 0, 0)), []),
                        UniformHole(BitVector((1, 1, 0, 0, 0)), [])
                    ])
                    UniformHole(BitVector((1, 1, 0, 0, 0)), [])
                ]
            )
        ])

        iterator = BFSIterator(grammar, partial_program, max_size=9)
        @test length(iterator) == 0
    end

    @testset "1 constraint: $name, $it" for (name, constraint) in ALL_CONSTRAINTS, it in ITERATORS
        # test all constraints individually, the constraints are chosen to prune the program space non-trivially
        if (it == BFSASPIterator || it == DFSASPIterator) && constraint isa ForbiddenSequence
            @test "Forbidden sequence not yet implemented for ASP iteterators" skip = true
        else
            test_constraint!(new_grammar(), constraint, max_size=6, allow_trivial=false, iterator=it)
        end
    end

    @testset "$n constraints: $it" for n ∈ 2:5, it in ITERATORS, _ in 1:10
        # test constraint interactions by randomly sampling constraints
        indices = randperm(length(ALL_CONSTRAINTS))[1:n]
        @testset let constraints = last.(ALL_CONSTRAINTS[indices]), it = it
            if (it == BFSASPIterator || it == DFSASPIterator) && any(x -> x isa ForbiddenSequence, constraints)
                @test "Forbidden sequence not yet implemented for ASP iteterators" skip = true
            else
                test_constraints!(new_grammar(), constraints, max_size=6, allow_trivial=true, iterator=it)
            end
        end
    end

    @testset "all constraints: $it" for it in [BFSIterator, BFSASPIterator]
        # all constraints combined, no valid solution exists
        grammar = new_grammar()
        for (_, constraint) ∈ ALL_CONSTRAINTS
            if !(it == BFSASPIterator && constraint isa ForbiddenSequence)
                addconstraint!(grammar, constraint)
            end
        end
        iter = it(grammar, :Int, max_size=10)
        @test length(iter) == 0
    end
end
