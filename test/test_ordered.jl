using HerbCore, HerbGrammar, HerbConstraints

@testset verbose=true "Ordered" begin

    function get_grammar_and_constraint1()
        grammar = @csgrammar begin
            Number = 1
            Number = x
            Number = Number + Number
        end
        constraint = Ordered(RuleNode(3, [
            VarNode(:a),
            VarNode(:b)
        ]), [:a, :b])
        return grammar, constraint
    end

    function get_grammar_and_constraint2()
        grammar = @csgrammar begin
            Number = Number + Number
            Number = 1
            Number = -Number
            Number = x
        end
        constraint = Ordered(RuleNode(1, [
            RuleNode(3, [VarNode(:a)]) ,
            RuleNode(3, [VarNode(:b)])
        ]), [:a, :b])
        return grammar, constraint
    end

    @testset "Number of candidate programs" begin
        for (grammar, constraint) in [get_grammar_and_constraint1(), get_grammar_and_constraint2()]
            iter = BFSIterator(grammar, :Number, solver=Solver(grammar, :Number), max_size=6)
            alltrees = 0
            validtrees = 0
            for p ∈ iter
                if check_tree(constraint, p)
                    validtrees += 1
                end
                alltrees += 1
            end

            addconstraint!(grammar, constraint)
            constraint_iter = BFSIterator(grammar, :Number, solver=Solver(grammar, :Number), max_size=6)

            @test validtrees > 0
            @test validtrees < alltrees
            @test length(collect(constraint_iter)) == validtrees
        end
    end
end
