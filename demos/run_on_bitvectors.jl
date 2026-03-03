using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints, HerbSpecification
using JSON, MLStyle

include("bit_functions.jl")
include("run_on_problem.jl")

benchmark = HerbBenchmarks.PBE_BV_Track_2018
benchmark_name = "SyGuS bitvectors"

problem_names = [String(s)[9:end] for s in names(benchmark; all=false) if startswith(String(s), "problem_")]
problem_names = problem_names[1:100]

property_grammar_extension = @cfgrammar begin
    Bool = Start == Start
    Bool = Start <= Start
    Bool = Start < Start
end

for n in problem_names
    full_problem = getfield(benchmark, Symbol("problem_", n))
    grammar = getfield(benchmark, Symbol("grammar_", n))

    problem = Problem(full_problem.name, full_problem.spec[1:min(end, 10)])

    results = run(
        benchmark = benchmark, 
        benchmark_name = benchmark_name,
        interpeter = interpret_sygus, 
        problem = problem,
        full_problem = full_problem,
        grammar = grammar,
        starting_symbol = :Start,
        property_grammar_extension = property_grammar_extension,
        property_symbol = :Bool,
        pool_size = 5,
        max_extension_depth = 1,
        max_extension_size = 1,
        max_property_depth = 4,
        max_property_size = 6,
        max_number_of_properties = 20,
        max_iterations = 500,
    )
    
    save(results)
end
