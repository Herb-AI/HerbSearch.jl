using HerbCore
using HerbGrammar
using HerbData
using HerbSearch

arithmetic_grammar_to_sample = @csgrammar begin
  X = |(1:5)
  X = x
  X = x
  X = x
  X = X * X
  X = X + X
  X = X - X
  X = (X)
end

dirpath = joinpath(@__DIR__, "problems")
mkpath(dirpath)

filename = "arithmetic_problems_generator.jl"
file_path = joinpath(dirpath, filename)

open(file_path,"w") do output
  create_problem = "
function create_problem(f)
  examples = [HerbData.IOExample(Dict(:x => x), f(x)) for x ∈ 1:meta_configuration.problem_range_size]
  return HerbData.Problem(examples)
end
"

  println(output,create_problem)

  problem_max_depth = 10
  for problem_index in 1:100
    arithmetic_rulenode = rand(RuleNode, arithmetic_grammar_to_sample, :X, problem_max_depth)
    arithmetic_problem = rulenode2expr(arithmetic_rulenode, arithmetic_grammar_to_sample)
    println(arithmetic_problem)
    println(output,"problem_$problem_index = create_problem(x -> $arithmetic_problem)")
    println(output)
  end
end