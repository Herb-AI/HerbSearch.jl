using Aqua
using DecisionTree: Leaf, Node
using HerbConstraints
using HerbCore
using HerbGrammar
using HerbInterpret
using HerbSearch
using HerbSpecification
using Test
using Documenter

DocMeta.setdocmeta!(HerbSearch, :DocTestSetup, :(using HerbSearch);
    recursive=true)

include("test_helpers.jl")
using Random
Random.seed!(1234)

@testset "HerbSearch.jl" verbose = true begin
	@testset "Aqua" Aqua.test_all(
		HerbSearch,
		piracies = (treat_as_own = [RuleNode, AbstractGrammar],),
	)
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
	include("test_budgeted_search.jl")
        include("test_bottom_up.jl")

	# 	# Excluded because it contains long tests
	# 	# include("test_realistic_searches.jl")
end

@testset verbose = true "Divide and conquer extension" begin
	include("test_divide_conquer.jl")
	include("test_divide_conquer_example.jl")
end

@testset verbose = true "AntiUnification" begin
	include("test_sketch_learning/test_anti_unify.jl")
        include("test_sketch_learning/test_anti_unify_utils.jl")
end


