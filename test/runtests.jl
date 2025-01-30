using HerbCore
using HerbSearch
using HerbGrammar
using HerbInterpret
using HerbConstraints
using HerbSpecification
using Clingo_jll, JSON # Enable RefactorExt
using Test
using Aqua

include("test_helpers.jl")
using Random
Random.seed!(1234)

@testset "HerbSearch.jl" verbose=true begin
    @testset "Aqua" Aqua.test_all(HerbSearch, piracies = (treat_as_own=[RuleNode, AbstractGrammar],))
    include("test_search_procedure.jl")        
    include("test_context_free_iterators.jl")
    include("test_sampling.jl")
    include("test_stochastic/test_stochastic.jl")
    include("test_genetic.jl")
    include("test_programiterator_macro.jl")

    include("test_uniform_iterator.jl")
    include("test_forbidden.jl")
    include("test_ordered.jl")
    include("test_contains.jl")
    include("test_contains_subtree.jl")
    include("test_unique.jl")

    include("test_constraints.jl")

    include("test_grammar_refactor/test_grammar_refactoring.jl")

    # Excluded because it contains long tests
    # include("test_realistic_searches.jl")
end
