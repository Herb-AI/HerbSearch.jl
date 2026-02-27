using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../properties.jl")
include("../search_alt.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_phone_9_short
inputs = [io.in for io in problem.spec]
grammar = benchmark.grammar_phone_9_short
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]
starting_symbol = grammar.rules[1]

property_grammar = deepcopy(grammar)
merge_grammars!(property_grammar, @cfgrammar begin
        ntInt = 1 | 2 | 3 | 4 | 5 | 6
        ntBool = ntString == ntString
        ntBool = ntInt == ntInt
        ntBool = ntInt <= ntInt
        ntBool = ntInt < ntInt
end)
add_rule!(property_grammar, Expr(:(=), starting_symbol, :_arg_out))
addconstraint!(property_grammar, Contains(length(property_grammar.rules)))
property_grammar_tags = benchmark.get_relevant_tags(property_grammar)
property_interpreter = (p, ys) -> [interpret_sygus(p, property_grammar_tags, (input[:_arg_out] = y; input)) for (y, input) in zip(ys, inputs)]

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
	max_depth = 4,
	max_size = 6,
)

@show length(properties)

search(
    problem = problem,
    grammar = grammar,
    interpreter = interpreter,
    properties = properties,
    starting_symbol = starting_symbol,
    max_iterations = 50,
    max_extension_depth = 2,
    max_extension_size = 4,
    observation_equivalance = true,
)

#=

With observational equivalance

Iteration:       1               Best score: 70/70               Best property: prefixof_cvc(substr_cvc(_arg_out, 1, 2), _arg_1)
Best outputs     ["+106 769-858-438", "+83 973-757-831", "+62 647-787-775", "+172 027-507-632", "+72 001-050-856", "+95 310-537-401", "+6 775-969-238"]
Best cost        0

Iteration:       2               Best score: 70/70               Best property: prefixof_cvc(at_cvc(_arg_1, 2), _arg_out)
Best outputs     [" +106 769-858-438", " +83 973-757-831", " +62 647-787-775", " +172 027-507-632", " +72 001-050-856", " +95 310-537-401", " +6 775-969-238"]
Best cost        0

Iteration:       3               Best score: 70/70               Best property: contains_cvc(substr_cvc(_arg_out, 1, 4), ".")
Best outputs     ["10", "83", "62", "17", "72", "95", "6 "]
Best cost        0

Iteration:       4               Best score: 70/70               Best property: contains_cvc(_arg_1, replace_cvc(_arg_out, ".", " "))
Best outputs     ["106.", "83.9", "62.6", "172.", "72.0", "95.3", "6.77"]
Best cost        0

Iteration:       5               Best score: 70/70               Best property: contains_cvc(substr_cvc(_arg_out, 1, 6), "+")
Best outputs     ["1.+106 769-858-438", "8.+83 973-757-831", "6.+62 647-787-775", "1.+172 027-507-632", "7.+72 001-050-856", "9.+95 310-537-401", "6.+6 775-969-238"]
Best cost        0

Iteration:       6               Best score: 70/70               Best property: contains_cvc(_arg_out, " ")
Best outputs     ["1.106 769-858-438", "8.83 973-757-831", "6.62 647-787-775", "1.172 027-507-632", "7.72 001-050-856", "9.95 310-537-401", "6.6 775-969-238"]
Best cost        0

Iteration:       7               Best score: 70/70               Best property: contains_cvc(_arg_out, "-")
Best outputs     ["1.769-858-438", "8.73-757-831", "6.47-787-775", "1.027-507-632", "7.01-050-856", "9.10-537-401", "6.5-969-238"]
Best cost        0

Solution found :)
replace_cvc(replace_cvc(replace_cvc(_arg_1, " ", "."), "-", "."), "+", substr_cvc(_arg_1, 4, 1))

=#