using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../properties.jl")
include("../search_alt.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_count_specific_characters_in_a_cell
inputs = [io.in for io in problem.spec]
grammar = benchmark.grammar_count_specific_characters_in_a_cell
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]

property_grammar = deepcopy(grammar)
merge_grammars!(property_grammar, @cfgrammar begin
    ntInt = 1 | 2 | 3 | 4
    ntBool = ntString == ntString
    ntBool = ntInt == ntInt
    ntBool = ntInt <= ntInt
    ntBool = ntInt < ntInt
    ntInt = _arg_out
end)
addconstraint!(property_grammar, Contains(length(property_grammar.rules)))
property_grammar_tags = benchmark.get_relevant_tags(property_grammar)
property_interpreter = (p, y) -> [interpret_sygus(p, property_grammar_tags, (input[:_arg_out] = y; input)) for input in inputs]

#=

	IOExample(Dict{Symbol, Any}(:_arg_1 => "Hannah", :_arg_2 => "n"), 2), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Hannah", :_arg_2 => "x"), 0), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Hannah", :_arg_2 => "N"), 0), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Hannah", :_arg_2 => "a"), 2), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Hannah", :_arg_2 => "h"), 1)])

=#

properties = generate_properties(;
    grammar = property_grammar,
    property_symbol = :ntBool,
    interpreter = property_interpreter,
	max_depth = 5,
	max_size = 6,
)

@show length(properties)

search(
    problem = problem,
    grammar = grammar,
    starting_symbol = :ntInt,
    interpreter = interpreter,
    properties = properties,
    max_iterations = 20,
    max_extension_depth = 3,
    max_extension_size = 5,
    observation_equivalance = true,
)

#=

Without observational equivalance
-- not using only invariant properties

Iteration:       1               Best score: 36          Best property: indexof_cvc(_arg_1, _arg_2, 1) <= _arg_out
Iteration:       1               Best cost:  0           Best outputs:  [3, -1, -1, 2, 6]

Iteration:       2               Best score: 33          Best property: suffixof_cvc(int_to_str_cvc(1), int_to_str_cvc(_arg_out))
Iteration:       2               Best cost:  0           Best outputs:  [2, 1, 1, 2, 1]

Iteration:       3               Best score: 21          Best property: prefixof_cvc(substr_cvc(_arg_1, 2, _arg_out), _arg_2)
Iteration:       3               Best cost:  1           Best outputs:  [2, 0, 0, 2, 0]

Solution found :)
len_cvc(replace_cvc(_arg_1, _arg_2, int_to_str_cvc(-1))) - len_cvc(_arg_1)
16{17{7{2,3,9{14}}},17{2}}
=#