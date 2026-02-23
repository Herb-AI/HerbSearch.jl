using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../properties.jl")
include("../search.jl")

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
property_interpreter = (p, y) -> [interpret_sygus(p, property_grammar_tags, (input[:_arg_out] = y; input)) for input in inputs]

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
    max_iterations = 10,
    observation_equivalance = true,
)

#=

With observational equivalance

Iteration:       1               Best score: 60          Best property: len_cvc(_arg_out) == 3
Iteration:       1               Best cost:  0           Best outputs:  ["-", "-", "-", "-", "-", "-"]

Iteration:       2               Best score: 60          Best property: prefixof_cvc(at_cvc(_arg_1, 5), _arg_out)
Iteration:       2               Best cost:  0           Best outputs:  ["   ", "   ", "   ", "   ", "   ", "   "]

Solution found :)
substr_cvc(substr_cvc(_arg_1, 5, len_cvc(_arg_1)), 1, 3)
7{7{2,13,16{2}},9,11}

=#