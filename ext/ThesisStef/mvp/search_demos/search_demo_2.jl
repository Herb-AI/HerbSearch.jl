using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../search.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_phone_1_short
inputs = [io.in for io in problem.spec]
grammar = benchmark.grammar_phone_1_short
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]
addconstraint!(grammar, Contains(2))

#=

	IOExample(Dict{Symbol, Any}(:_arg_1 => "938-242-504"), "242"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "308-916-545"), "916"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "623-599-749"), "599"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "981-424-843"), "424"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "118-980-214"), "980"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "244-655-094"), "655")])

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
    properties = collect(zip(properties, property_representations)),
    max_iterations = 5,
)