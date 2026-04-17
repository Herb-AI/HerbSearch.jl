using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../search.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_clean_and_reformat_telephone_numbers
inputs = [io.in for io in problem.spec]
grammar = benchmark.grammar_clean_and_reformat_telephone_numbers
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]
addconstraint!(grammar, Contains(2))

#=

	IOExample(Dict{Symbol, Any}(:_arg_1 => "801-456-8765"), "8014568765"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "<978> 654-0299"), "9786540299"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "978.654.0299"), "9786540299")])

=#

properties = vcat(
    [(x, y) -> occursin(c, y)               for c in " +-,.0123456789"],
    [(x, y) -> startswith(y, c)             for c in " +-,.0123456789"],
    [(x, y) -> endswith(y, c)               for c in " +-,.0123456789"],

    [(x, y) -> length(y) >= n ? y[n] == c : false for n in 1:10 for c in " +-,.0123456789"],
    [(x, y) -> length(y) >= n1 ? y[n1] == x[:_arg_1][n2] : false for n1 in 1:10 for n2 in 1:10],

    [(x, y) -> length(y) == n               for n in 1:10],
    [(x, y) -> length(y) >= n               for n in 1:10],
    [(x, y) -> length(y) <= n               for n in 1:10],

    [(x, y) -> length(y) == length(x[:_arg_1]) + n  for n in 1:10],
    [(x, y) -> length(y) >= length(x[:_arg_1]) + n  for n in 1:10],
    [(x, y) -> length(y) <= length(x[:_arg_1]) + n  for n in 1:10],

    [(x, y) -> length(y) == length(x[:_arg_1]) - n  for n in 1:10],
    [(x, y) -> length(y) >= length(x[:_arg_1]) - n  for n in 1:10],
    [(x, y) -> length(y) <= length(x[:_arg_1]) - n  for n in 1:10],
)

property_representations = vcat(
    ["occursin('$c', y)"               for c in " +-,.0123456789"],
    ["startswith(y, '$c')"             for c in " +-,.0123456789"],
    ["endswith(y, '$c')"               for c in " +-,.0123456789"],

    ["length(y) >= $n ? y[$n] == '$c' : false" for n in 1:10 for c in " +-,.0123456789"],
    ["length(y) >= $n1 ? y[$n1] == x[:_arg_1][$n2] : false" for n1 in 1:10 for n2 in 1:10],

    ["length(y) == $n"               for n in 1:10],
    ["length(y) >= $n"               for n in 1:10],
    ["length(y) <= $n"               for n in 1:10],

    ["length(y) == length(x[:_arg_1]) + $n"  for n in 1:10],
    ["length(y) >= length(x[:_arg_1]) + $n"  for n in 1:10],
    ["length(y) <= length(x[:_arg_1]) + $n"  for n in 1:10],

    ["length(y) == length(x[:_arg_1]) - $n"  for n in 1:10],
    ["length(y) >= length(x[:_arg_1]) - $n"  for n in 1:10],
    ["length(y) <= length(x[:_arg_1]) - $n"  for n in 1:10],
)

search(
    problem = problem,
    grammar = grammar,
    interpreter = interpreter,
    properties = zip(properties, property_representations),
    max_iterations = 50,
)