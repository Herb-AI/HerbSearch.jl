using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../properties.jl")
include("../search_alt.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_clean_and_reformat_telephone_numbers
inputs = [io.in for io in problem.spec]
grammar = benchmark.grammar_clean_and_reformat_telephone_numbers
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]
starting_symbol = grammar.rules[1]


property_grammar = deepcopy(grammar)
merge_grammars!(property_grammar, @cfgrammar begin
    ntBool = ntString == ntString
    ntBool = ntInt == ntInt
    ntString = _arg_out
end)
addconstraint!(property_grammar, Contains(length(property_grammar.rules)))
property_grammar_tags = benchmark.get_relevant_tags(property_grammar)
property_interpreter = (p, ys) -> [interpret_sygus(p, property_grammar_tags, (input[:_arg_out] = y; input)) for (y, input) in zip(ys, inputs)]

#=

	IOExample(Dict{Symbol, Any}(:_arg_1 => "801-456-8765"), "8014568765"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "<978> 654-0299"), "9786540299"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "978.654.0299"), "9786540299")])

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

Iteration:       1               Best score: 30/30               Best property: contains_cvc(replace_cvc(_arg_out, "", _arg_1), _arg_out)
Best outputs     ["801-456-8765", "<978> 654-0299", "978.654.0299"]
Best cost        0

Iteration:       2               Best score: 30/30               Best property: -1 == str_to_int_cvc(_arg_out)
Best outputs     ["-1", "-1", "-1"]
Best cost        0

Iteration:       3               Best score: 30/30               Best property: contains_cvc(int_to_str_cvc(len_cvc(_arg_out)), int_to_str_cvc(1))
Best outputs     ["12", "14", "12"]
Best cost        0

Iteration:       4               Best score: 20/20               Best property: contains_cvc(int_to_str_cvc(len_cvc(_arg_out)), int_to_str_cvc(0))
Best outputs     ["8014568765", "<978> 6540299", "9786540299"]
Best cost        1

Iteration:       5               Best score: 10/10               Best property: prefixof_cvc("<", _arg_out)
Best outputs     ["8014568765", "<978> 6540299", "9786540299"]
Best cost        2

Iteration:       6               Best score: 10/10               Best property: contains_cvc(_arg_out, " ")
Best outputs     ["8014568765", ">978> 6540299", "9786540299"]
Best cost        2

Solution found :)
replace_cvc(replace_cvc(replace_cvc(replace_cvc(_arg_1, "<", ""), concat_cvc(">", " "), ""), ".", ""), "-", "")

=#