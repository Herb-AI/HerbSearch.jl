using Aqua
using DecisionTree: Leaf, Node
using Documenter
using HerbConstraints
using HerbCore
using HerbGrammar
using HerbInterpret
using HerbSearch
using HerbSpecification
using Test
using JSON
using Clingo_jll
using ReTestItems

DocMeta.setdocmeta!(HerbSearch, :DocTestSetup, :(using HerbCore,
        HerbConstraints, HerbGrammar, HerbSearch); recursive=true)

include("setup.jl")
include("test_helpers.jl")
using Random
Random.seed!(1234)
runtests()

# @testset "HerbSearch.jl" verbose = true begin
#     @testset "Aqua" Aqua.test_all(
#         HerbSearch,
#         piracies=(treat_as_own=[RuleNode, AbstractGrammar],),
#     )
#     include("search_procedure_test.jl")
#     include("context_free_iterators_test.jl")
#     include("sampling_test.jl")
#     include("test_stochastic/test_stochastic.jl")
#     include("genetic_test.jl")
#     include("programiterator_macro_test.jl")
#     include("uniform_iterator_test.jl")
#     include("forbidden_test.jl")
#     include("ordered_test.jl")
#     include("contains_test.jl")
#     include("contains_subtree_test.jl")
#     include("unique_test.jl")
#     include("constraints_test.jl")
#     include("bottom_up_test.jl")
#     include("uniform_asp_iterator_test.jl")
#     include("asp_iterator_test.jl")

#     include("compression_test.jl")
#     include("add_compressed_rules_test.jl")

#     # Excluded because it contains long tests
#     # include("realistic_searches_test.jl")
#     @testset verbose = true "Divide and conquer extension" begin
#         include("divide_conquer_test.jl")
#         include("divide_conquer_example_test.jl")
#     end
#     doctest(HerbSearch; manual=false)
# end
