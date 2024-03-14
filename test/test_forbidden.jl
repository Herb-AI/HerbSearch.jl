using HerbCore, HerbGrammar, HerbConstraints

@testset verbose=true "Forbidden" begin

    @testset "Number of candidate programs" begin
        #with constraints
        grammar = @csgrammar begin
            Number = x | 1
            Number = Number + Number
            Number = Number - Number
        end

        #without constraints
        iter = BFSIterator(grammar, :Number, solver=GenericSolver(grammar, :Number), max_depth=3)
        @test length(collect(iter)) == 202
        
        constraint = Forbidden(RuleNode(4, [RuleNode(1), RuleNode(1)]))
        addconstraint!(grammar, constraint)

        #with constraints
        iter = BFSIterator(grammar, :Number, solver=GenericSolver(grammar, :Number), max_depth=3)
        @test length(collect(iter)) == 163
    end

    @testset "Jump Start" begin
        grammar = @csgrammar begin
            Number = 1 | x
            Number = Number + Number
        end

        constraint = Forbidden(RuleNode(3, [VarNode(:x), VarNode(:x)]))
        addconstraint!(grammar, constraint)

        solver = GenericSolver(grammar, :Number)
        #jump start with new_state!
        new_state!(solver, RuleNode(3, [Hole(get_domain(grammar, :Number)), Hole(get_domain(grammar, :Number))]))
        iter = BFSIterator(grammar, :Number, solver=solver, max_depth=3)

        @test length(collect(iter)) == 12
        # 3{2,1}
        # 3{1,2}
        # 3{3{1,2}1}
        # 3{3{2,1}1}
        # 3{3{2,1}2}
        # 3{3{1,2}2}
        # 3{1,3{1,2}}
        # 3{2,3{1,2}}
        # 3{2,3{2,1}}
        # 3{1,3{2,1}}
        # 3{3{2,1}3{1,2}}
        # 3{3{1,2}3{2,1}}
    end

    @testset "Large Tree" begin
        grammar = @csgrammar begin
            Number = x | 1
            Number = Number + Number
            Number = Number - Number
        end

        constraint = Forbidden(RuleNode(4, [VarNode(:x), VarNode(:x)]))
        addconstraint!(grammar, constraint)

        partial_tree = RuleNode(4, [
            RuleNode(4, [
                RuleNode(3, [
                    RuleNode(1), 
                    RuleNode(1)
                ]), 
                FixedShapedHole(BitVector((1, 1, 0, 0)), [])
            ]), 
            FixedShapedHole(BitVector((0, 0, 1, 1)), [
                RuleNode(3, [
                    RuleNode(1), 
                    RuleNode(1)
                ]), 
                RuleNode(1)
            ]), 
        ])

        solver = GenericSolver(grammar, :Number)
        iter = BFSIterator(grammar, :Number, solver=solver)
        new_state!(solver, partial_tree)
        trees = collect(iter)
        @test length(trees) == 3 # 3 out of the 4 combinations to fill the FixedShapedHoles are valid
    end
end
