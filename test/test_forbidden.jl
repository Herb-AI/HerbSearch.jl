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
        iter = BFSIterator(grammar, :Number, solver=Solver(grammar, :Number), max_depth=3)
        @test length(collect(iter)) == 202
        
        constraint = Forbidden(RuleNode(4, [RuleNode(1), RuleNode(1)]))
        addconstraint!(grammar, constraint)

        #with constraints
        iter = BFSIterator(grammar, :Number, solver=Solver(grammar, :Number), max_depth=3)
        @test length(collect(iter)) == 163
    end
end
