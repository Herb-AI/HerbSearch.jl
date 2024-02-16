using HerbBenchmarks.PBE_SLIA_Track_2019

using HerbInterpret
using HerbGrammar
using HerbSearch
import Logging


Logging.disable_logging(Logging.LogLevel(1))
grammar = grammar_12948338
problem = problem_12948338
algorithm = get_mh_enumerator(problem.examples, HerbSearch.mean_squared_error)

program, cost, rulenode = search_best(
  grammar, 
  problem, 
  :Start, 
  enumerator=algorithm, 
  error_function=mse_error_function, 
  max_depth=4, 
  max_time=5,
  allow_evaluation_errors=true
)
println("Answer")
println("Program is:" ,program)
println("Cost: ", cost)

results = HerbInterpret.evaluate_program(rulenode, problem.examples, grammar, HerbInterpret.test_with_input)
println(results)
println("Cost: ", HerbSearch.mean_squared_error(results))

symboltable :: SymbolTable = SymbolTable(grammar)
for example ∈ problem.examples
  output = test_with_input(symboltable, program, example.in)
  println(output, " ", example.out, HerbSearch.mse_error_function(output, example.out))
  println()
end
