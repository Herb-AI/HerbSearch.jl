using HerbCore
using HerbSearch
using HerbGrammar
using HerbInterpret
using HerbConstraints
using HerbSpecification
using Test

include("test_helpers.jl")
using Random
Random.seed!(1234)

@testset "HerbSearch.jl" verbose = true begin
	# include("test_search_procedure.jl")        
	# include("test_divide_conquer.jl")
	include("test_divide_conquer_example.jl")
	# include("test_context_free_iterators.jl")
	# include("test_sampling.jl")
	# include("test_stochastic/test_stochastic.jl")
	# include("test_genetic.jl")
	# include("test_programiterator_macro.jl")

	# include("test_uniform_iterator.jl")
	# include("test_forbidden.jl")
	# include("test_ordered.jl")
	# include("test_contains.jl")
	# include("test_contains_subtree.jl")
	# include("test_unique.jl")

	# include("test_constraints.jl")
	# TODO: uncomment above, not below
	# ----
	# Excluded because it contains long tests
	# include("test_realistic_searches.jl")
end
