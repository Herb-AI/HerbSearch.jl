using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints, HerbSpecification
using JSON, MLStyle

include("string_functions.jl")
include("run_on_problem.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
benchmark_name = "SyGuS strings"

problem_names = [String(s)[9:end] for s in names(benchmark; all=false) if startswith(String(s), "problem_")]
# problem_names = problem_names[2:2]

property_grammar_extension = @cfgrammar begin
    ntInt = 1 | 2 | 3 | 4 | 5
    ntBool = ntString == ntString
    ntBool = ntInt == ntInt
    ntBool = ntInt <= ntInt
    ntBool = ntInt < ntInt
end

problem_names = ["17212077"]

for n in problem_names
    problem  = getfield(benchmark, Symbol("problem_", n))
    grammar  = getfield(benchmark, Symbol("grammar_", n))

    if length(problem.spec) >= 10
        continue
    end

    results = run(
        benchmark = benchmark, 
        benchmark_name = benchmark_name,
        interpeter = interpret_sygus, 
        problem = problem,
        full_problem = problem,
        grammar = grammar,
        property_grammar_extension = property_grammar_extension,
        property_symbol = :ntBool,
        pool_size = 100,
        max_extension_depth = 2,
        max_extension_size = 4,
        max_property_depth = 4,
        max_property_size = 6,
        max_number_of_properties = 5,
        max_iterations = 1000,
    )
    
    # save(results)
end
