using HerbCore, HerbGrammar, HerbConstraints

@testset verbose=true "Contains" begin

    @testset "Permutation grammar" begin
        # A grammar that represents all permutations of (1, 2, 3, 4, 5)
        grammar = @csgrammar begin
            N = |(1:5)
            Permutation = (N, N, N, N, N)
        end
        addconstraint!(grammar, Contains(1))
        addconstraint!(grammar, Contains(2))
        addconstraint!(grammar, Contains(3))
        addconstraint!(grammar, Contains(4))
        addconstraint!(grammar, Contains(5))

        # There are 5! = 120 permutations of 5 distinct elements
        iter = BFSIterator(grammar, :Permutation, solver=GenericSolver(grammar, :Permutation))
        @test count_expressions(iter) == 120
    end
end
