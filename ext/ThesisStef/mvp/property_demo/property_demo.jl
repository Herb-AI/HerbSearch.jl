using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../properties.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_phone_9_short
inputs = [io.in for io in problem.spec]
target_outputs = [io.out for io in problem.spec]
property_grammar = benchmark.grammar_phone_9_short

merge_grammars!(property_grammar, @cfgrammar begin
    ntString = _arg_out
end)
addconstraint!(property_grammar, Contains(length(property_grammar.rules)))

property_grammar_tags = benchmark.get_relevant_tags(property_grammar)
property_interpreter = (p, y) -> [interpret_sygus(p, property_grammar_tags, (input[:_arg_out] = y; input)) for input in inputs]


properties = generate_properties(;
    grammar = property_grammar,
    property_symbol = :ntBool,
    interpreter = property_interpreter,
	max_depth = 3,
	max_size = 3,
)

for (prop, repr) in properties
    @show repr
    @show prop(inputs[1], target_outputs[1])
end

#=

	IOExample(Dict{Symbol, Any}(:_arg_1 => "+106 769-858-438"), "106.769.858.438"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+83 973-757-831"), "83.973.757.831"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+62 647-787-775"), "62.647.787.775"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+172 027-507-632"), "172.027.507.632"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+72 001-050-856"), "72.001.050.856"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+95 310-537-401"), "95.310.537.401"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+6 775-969-238"), "6.775.969.238")])


=#