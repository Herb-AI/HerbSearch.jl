@testsetup module HerbSearchSetup
using DecisionTree: Leaf, Node
using Test
using Aqua

using JSON
using Clingo_jll
using HerbCore
using HerbSearch
using HerbGrammar
using HerbInterpret
using HerbConstraints
using HerbSpecification

for mod in (HerbCore, HerbSearch, HerbGrammar, HerbInterpret, HerbConstraints, HerbSpecification)
    for name in names(mod)
        name in (:eval, :include) && continue
        @eval export $name
    end
end
export Leaf, Node, JSON, Clingo_jll

using Random
Random.seed!(1234)

include("test_helpers.jl")
export parametrized_test, create_problem, test_constraints!, test_constraint!
end

