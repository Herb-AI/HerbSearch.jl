include("../../src/Herb.jl")
using .Herb
using Logging
using StatsBase

grammar = Herb.HerbGrammar.@cfgrammar begin 
    C = |(1:5)
    X = |(1:5)
    X = C * X
    X = X + X 
    X = X * X
    X = x
end 

# disable_logging(LogLevel(1))
examples_hard = [Herb.HerbData.IOExample(Dict(:x => x), x * (x + 5) + 2) for x ∈ 1:10]
problem = Herb.HerbData.Problem(examples_hard, "example")

enumerator = HerbSearch.get_sa_enumeratorg(grammar, examples_hard, 4, :X, HerbSearch.mean_squared_error)
@time work = Herb.HerbSearch.search_it(grammar, problem, enumerator)
println(work)