@testitem "ContainsSubtree" begin
    using HerbCore, HerbGrammar, HerbConstraints
    using HerbSearch: BFSASPIterator, DFSASPIterator
    include("test_helpers.jl")

    const TOPDOWNITERATORS = [BFSASPIterator, DFSASPIterator, BFSIterator, DFSASPIterator]

    @testset "ContainsSubtree: $it" for it in TOPDOWNITERATORS
        @testset "Minimal Example" begin
            grammar = @csgrammar begin
                Int = x
                Int = Int + Int
                Int = Int + Int
                Int = 1
            end

            constraint = ContainsSubtree(
                RuleNode(2, [
                    RuleNode(1),
                    RuleNode(2, [
                        RuleNode(1),
                        RuleNode(1)
                    ])
                ])
            )

            test_constraint!(grammar, constraint, max_size=6, iterator=it)
        end

        @testset "1 VarNode" begin
            grammar = @csgrammar begin
                Int = x
                Int = Int + Int
                Int = Int + Int
                Int = 1
            end

            constraint = ContainsSubtree(
                RuleNode(2, [
                    RuleNode(1),
                    VarNode(:x)
                ])
            )

            test_constraint!(grammar, constraint, max_size=6, iterator=it)
        end

        @testset "2 VarNodes" begin
            grammar = @csgrammar begin
                Int = x
                Int = Int + Int
                Int = Int + Int
                Int = 1
            end

            constraint = ContainsSubtree(
                RuleNode(2, [
                    VarNode(:x),
                    VarNode(:x)
                ])
            )

            test_constraint!(grammar, constraint, max_size=6, iterator=it)
        end


        @testset "No StateHoles" begin
            grammar = @csgrammar begin
                Int = x
                Int = Int + Int
            end

            constraint = ContainsSubtree(
                RuleNode(2, [
                    RuleNode(1),
                    RuleNode(2, [
                        RuleNode(1),
                        RuleNode(1)
                    ])
                ])
            )

            test_constraint!(grammar, constraint, max_size=6, iterator=it)
        end

        @testset "Permutations" begin
            # A grammar that represents all permutations of (1, 2, 3, 4, 5)
            grammar = @csgrammar begin
                N = |(1:5)
                Permutation = (N, N, N, N, N)
            end
            addconstraint!(grammar, ContainsSubtree(RuleNode(1)))
            addconstraint!(grammar, ContainsSubtree(RuleNode(2)))
            addconstraint!(grammar, ContainsSubtree(RuleNode(3)))
            addconstraint!(grammar, ContainsSubtree(RuleNode(4)))
            addconstraint!(grammar, ContainsSubtree(RuleNode(5)))

            # There are 5! = 120 permutations of 5 distinct elements
            iter = it(grammar, :Permutation)
            @test length(iter) == 120
        end
    end
end
