using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../properties.jl")
include("../search_alt.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_phone_1_short
inputs = [io.in for io in problem.spec]
grammar = benchmark.grammar_phone_1_short
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]

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

	IOExample(Dict{Symbol, Any}(:_arg_1 => "938-242-504"), "242"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "308-916-545"), "916"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "623-599-749"), "599"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "981-424-843"), "424"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "118-980-214"), "980"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "244-655-094"), "655")])

=#

properties = generate_properties(;
    grammar = property_grammar,
    property_symbol = :ntBool,
    interpreter = property_interpreter,
	max_depth = 4,
	max_size = 6,
)

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

Iteration:       1               Best score: 60/60               Best property: len_cvc(_arg_out) == 3
Best outputs     ["938-242-504", "308-916-545", "623-599-749", "981-424-843", "118-980-214", "244-655-094"]
Best cost        0

Iteration:       2               Best score: 60/60               Best property: prefixof_cvc(at_cvc(_arg_1, 5), _arg_out)
Best outputs     ["938", "308", "623", "981", "118", "244"]
Best cost        0

Solution found :)
substr_cvc(_arg_1, 5, 5 + 2)

=#