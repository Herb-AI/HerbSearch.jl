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
starting_symbol = grammar.rules[1]

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
property_interpreter = (p, ys) -> [interpret_sygus(p, property_grammar_tags, (input[:_arg_out] = y; input)) for (y, input) in zip(ys, inputs)]

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
	max_size = 7,
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

Iteration:       1               Best score: 34/39               Best property: prefixof_cvc(substr_cvc(_arg_1, _arg_out, 2), _arg_1)
Best outputs     [1, 1, 1, 1, 1]
Best cost        0
Best program     1

Iteration:       2               Best score: 38/40               Best property: 3 <= str_to_int_cvc(at_cvc(int_to_str_cvc(_arg_out), 1))
Best outputs     [3, -1, -1, 2, 6]
Best cost        1
Best program     indexof_cvc(_arg_1, _arg_2, 1)

Iteration:       3               Best score: 30/32               Best property: prefixof_cvc(at_cvc(_arg_1, _arg_out), _arg_1)
Best outputs     [0, 0, 0, 0, 0]
Best cost        3
Best program     0

Iteration:       4               Best score: 29/33               Best property: _arg_out == len_cvc(at_cvc(int_to_str_cvc(-1), _arg_out))
Best outputs     [0, 0, 0, 0, 0]
Best cost        6
Best program     0

Iteration:       5               Best score: 40/40               Best property: 3 <= _arg_out
Best outputs     [3, 13, 13, 2, 6]
Best cost        6
Best program     indexof_cvc(concat_cvc(_arg_1, concat_cvc(_arg_1, _arg_2)), _arg_2, 1)

Iteration:       6               Best score: 30/30               Best property: prefixof_cvc(substr_cvc(_arg_1, 2, _arg_out), _arg_1)
Best outputs     [0, 0, 0, 0, 0]
Best cost        9
Best program     0

Iteration:       7               Best score: 37/40               Best property: 2 < str_to_int_cvc(at_cvc(int_to_str_cvc(_arg_out), 1))
Best outputs     [3, -1, -1, 2, 6]
Best cost        11
Best program     indexof_cvc(_arg_1, _arg_2, 1)

Iteration:       8               Best score: 30/30               Best property: prefixof_cvc(substr_cvc(_arg_1, 2, _arg_out), _arg_2)
Best outputs     [0, 0, 0, 0, 0]
Best cost        12
Best program     0

Iteration:       9               Best score: 30/30               Best property: prefixof_cvc(substr_cvc(_arg_1, 2, _arg_out), "")
Best outputs     [0, 0, 0, 0, 0]
Best cost        15
Best program     0

Iteration:       10              Best score: 20/20               Best property: prefixof_cvc(at_cvc(_arg_1, _arg_out), _arg_2)
Best outputs     [3, 0, 0, 2, 0]
Best cost        11
Best program     indexof_cvc(replace_cvc(_arg_1, _arg_2, concat_cvc(_arg_2, _arg_1)), _arg_1, 1) + -1

Iteration:       11              Best score: 10/10               Best property: 2 == _arg_out
Best outputs     [3, 0, 0, 2, 1]
Best cost        6
Best program     indexof_cvc(replace_cvc(replace_cvc(_arg_1, concat_cvc(replace_cvc(_arg_1, _arg_2, ""), _arg_2), _arg_2), _arg_2, concat_cvc(_arg_2, _arg_1)), _arg_1, 1) + -1

Iteration:       12              Best score: 40/40               Best property: _arg_out <= 2
Best outputs     [3, 13, 13, 2, 6]
Best cost        18
Best program     indexof_cvc(concat_cvc(_arg_1, concat_cvc(_arg_1, _arg_2)), _arg_2, 1)

Iteration:       13              Best score: 20/20               Best property: suffixof_cvc(at_cvc(_arg_1, _arg_out), _arg_2)
Best outputs     [2, 0, 0, 0, 0]
Best cost        15
Best program     indexof_cvc(replace_cvc(_arg_1, concat_cvc(_arg_2, _arg_2), _arg_1), _arg_1, 1) + -1

Iteration:       14              Best score: 20/20               Best property: 1 == _arg_out
Best outputs     [2, 0, 0, 1, 5]
Best cost        17
Best program     indexof_cvc(replace_cvc(_arg_1, _arg_2, _arg_1), _arg_1, 1) + -1

Iteration:       15              Best score: 20/20               Best property: contains_cvc(at_cvc(_arg_1, _arg_out), _arg_2)
Best outputs     [2, 0, 0, 0, 0]
Best cost        18
Best program     indexof_cvc(replace_cvc(_arg_1, concat_cvc(_arg_2, _arg_2), _arg_1), _arg_1, 1) + -1

Iteration:       16              Best score: 20/20               Best property: _arg_out == 1
Best outputs     [2, 0, 0, 1, 5]
Best cost        20
Best program     indexof_cvc(replace_cvc(_arg_1, _arg_2, _arg_1), _arg_1, 1) + -1

Iteration:       17              Best score: 20/20               Best property: prefixof_cvc(_arg_1, at_cvc(int_to_str_cvc(-1), _arg_out))
Best outputs     [2, 0, 0, 0, 0]
Best cost        21
Best program     indexof_cvc(replace_cvc(_arg_1, concat_cvc(_arg_2, _arg_2), _arg_1), _arg_1, 1) + -1

Iteration:       18              Best score: 20/20               Best property: 2 <= _arg_out
Best outputs     [2, 0, 0, 1, 5]
Best cost        23
Best program     indexof_cvc(replace_cvc(_arg_1, _arg_2, _arg_1), _arg_1, 1) + -1


=#