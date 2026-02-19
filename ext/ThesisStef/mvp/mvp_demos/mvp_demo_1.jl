using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../properties.jl")
include("../search.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_phone_9_short
inputs = [io.in for io in problem.spec]
grammar = benchmark.grammar_phone_9_short
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]

property_grammar = deepcopy(grammar)
merge_grammars!(property_grammar, @cfgrammar begin
    ntBool = ntString == ntString
    ntString = _arg_out
end)
addconstraint!(property_grammar, Contains(length(property_grammar.rules)))
property_grammar_tags = benchmark.get_relevant_tags(property_grammar)
property_interpreter = (p, y) -> [interpret_sygus(p, property_grammar_tags, (input[:_arg_out] = y; input)) for input in inputs]

#=

	IOExample(Dict{Symbol, Any}(:_arg_1 => "+106 769-858-438"), "106.769.858.438"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+83 973-757-831"), "83.973.757.831"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+62 647-787-775"), "62.647.787.775"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+172 027-507-632"), "172.027.507.632"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+72 001-050-856"), "72.001.050.856"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+95 310-537-401"), "95.310.537.401"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+6 775-969-238"), "6.775.969.238")])

=#

properties = generate_properties(;
    grammar = property_grammar,
    property_symbol = :ntBool,
    interpreter = property_interpreter,
	max_depth = 3,
	max_size = 5,
)

search(
    problem = problem,
    grammar = grammar,
    interpreter = interpreter,
    properties = properties,
    max_iterations = 10,
)

#=

Iteration: 1             Property: prefixof_cvc(at_cvc(_arg_1, 2), _arg_out)
Iteration: 2             Property: contains_cvc(_arg_out, ".")
Iteration: 3             Property: contains_cvc(_arg_out, at_cvc(_arg_1, 3))
Iteration: 4             Property: contains_cvc(_arg_out, "-")
Iteration: 5             Property: prefixof_cvc(_arg_1, at_cvc(_arg_out, 3))

Solution found :)
replace_cvc(substr_cvc(replace_cvc(_arg_1, "-", "."), 2, len_cvc(_arg_1)), " ", ".")
8{10{8{2,5,6},13,19{2}},3,6}

=#