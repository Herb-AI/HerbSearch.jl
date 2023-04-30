include("../../src/Herb.jl")
using .Herb
using Logging
using StatsBase

# grammar defintion
grammar = Herb.HerbGrammar.@cfgrammar begin 
    C = |(1:5)
    X = |(1:5)
    X = C * X
    X = X + X 
    X = X * X
    X = x
end 

# Expression to find x * (x + 5) + 2 with 10 examples
examples = [Herb.HerbData.IOExample(Dict(:x => x), x * (x + 5) + 2) for x ∈ 1:10]
problem = Herb.HerbData.Problem(examples, "example")

# enumerator using as cost the number of correct test cases
enumerator_bad = Herb.HerbSearch.get_mh_enumerator(grammar, examples, 5, :X, HerbSearch.misclassification)

# eunmerator using as cost function mean_squared_error
enumerator_good = Herb.HerbSearch.get_mh_enumerator(grammar, examples, 5, :X, HerbSearch.mean_squared_error)
@time work = Herb.HerbSearch.search_it(grammar, problem, enumerator_good)
println(work)