@testitem "UniformIterators" begin
    using HerbGrammar, HerbConstraints, HerbCore
    using HerbSearch: UniformASPIterator
    using HerbConstraints: ASPSolver
    using Clingo_jll

    const UNIFORM = [(ASPSolver, UniformASPIterator), (UniformSolver, UniformIterator)]

    function create_dummy_grammar_and_tree_128programs()
        grammar = @csgrammar begin
            Number = Number + Number
            Number = Number - Number
            Number = Number * Number
            Number = Number / Number
            Number = x | 1 | 2 | 3
        end

        uniform_tree = RuleNode(1, [
            UniformHole(
                BitVector((1, 1, 1, 1, 0, 0, 0, 0)),
                [
                    UniformHole(BitVector((0, 0, 0, 0, 1, 1, 1, 1)), [])
                    UniformHole(BitVector((0, 0, 0, 0, 1, 0, 0, 1)), [])
                ]
            ),
            UniformHole(BitVector((0, 0, 0, 0, 1, 1, 1, 1)), [])
        ])
        # 4 * 4 * 2 * 4 = 128 programs without constraints

        return grammar, uniform_tree
    end

    @testset "Without constraints: $it" for (sol, it) in UNIFORM
        grammar, uniform_tree = create_dummy_grammar_and_tree_128programs()
        uniform_solver = sol(grammar, uniform_tree)
        uniform_iterator = it(uniform_solver, nothing)
        @test length(uniform_iterator) == 128
    end

    @testset "Forbidden constraint: $it" for (sol, it) in UNIFORM
        #forbid "a - a"
        grammar, uniform_tree = create_dummy_grammar_and_tree_128programs()
        addconstraint!(grammar, Forbidden(RuleNode(2, [VarNode(:a), VarNode(:a)])))
        uniform_solver = sol(grammar, uniform_tree)
        uniform_iterator = it(uniform_solver, nothing)
        @test length(uniform_iterator) == 120

        #forbid all rulenodes
        grammar, uniform_tree = create_dummy_grammar_and_tree_128programs()
        addconstraint!(grammar, Forbidden(VarNode(:a)))
        uniform_solver = sol(grammar, uniform_tree)
        uniform_iterator = it(uniform_solver, nothing)
        @test length(uniform_iterator) == 0
    end

    @testset "The root is the only solution: $it" for (sol, it) in UNIFORM
        grammar = @csgrammar begin
            S = 1
        end

        uniform_solver = sol(grammar, RuleNode(1))
        uniform_iterator = it(uniform_solver, nothing)

        @test next_solution!(uniform_iterator) == RuleNode(1)
        @test isnothing(next_solution!(uniform_iterator))
    end

    @testset "No solutions (ordered constraint): $it" for (sol, it) in UNIFORM
        grammar = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + Number
            Number = Number - Number
        end
        constraint1 = Ordered(RuleNode(3, [
                VarNode(:a),
                VarNode(:b)
            ]), [:a, :b])
        constraint2 = Ordered(RuleNode(4, [
                VarNode(:a),
                VarNode(:b)
            ]), [:a, :b])
        addconstraint!(grammar, constraint1)
        addconstraint!(grammar, constraint2)

        tree = UniformHole(BitVector((0, 0, 1, 1)), [
            UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ]),
            UniformHole(BitVector((1, 1, 0, 0)), [])
        ])
        uniform_solver = sol(grammar, tree)
        uniform_iterator = it(uniform_solver, nothing)
        @test isnothing(next_solution!(uniform_iterator))
    end

    @testset "No solutions (forbidden constraint): $it" for (sol, it) in UNIFORM
        grammar = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + Number
            Number = Number - Number
        end
        constraint1 = Forbidden(RuleNode(3, [
            VarNode(:a),
            VarNode(:b)
        ]))
        constraint2 = Forbidden(RuleNode(4, [
            VarNode(:a),
            VarNode(:b)
        ]))
        addconstraint!(grammar, constraint1)
        addconstraint!(grammar, constraint2)

        tree = UniformHole(BitVector((0, 0, 1, 1)), [
            UniformHole(BitVector((0, 0, 1, 1)), [
                UniformHole(BitVector((1, 1, 0, 0)), []),
                UniformHole(BitVector((1, 1, 0, 0)), [])
            ]),
            UniformHole(BitVector((1, 1, 0, 0)), [])
        ])
        uniform_solver = sol(grammar, tree)
        uniform_iterator = it(uniform_solver, nothing)
        @test isnothing(next_solution!(uniform_iterator))
    end
end
