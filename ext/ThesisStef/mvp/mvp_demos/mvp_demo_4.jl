using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../properties.jl")
include("../search.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_clean_and_reformat_telephone_numbers
inputs = [io.in for io in problem.spec]
grammar = benchmark.grammar_clean_and_reformat_telephone_numbers
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

search(
    problem = problem,
    grammar = grammar,
    interpreter = interpreter,
    properties = properties,
    max_iterations = 20,
)

#=

Iteration:       1               Best score: 30          Best property: contains_cvc(concat_cvc(_arg_1, ","), _arg_out)
Iteration:       1               Best cost:  0           Best outputs:  ["0", "0", "0"]

Iteration:       2               Best score: 30          Best property: prefixof_cvc("-", _arg_out)
Iteration:       2               Best cost:  0           Best outputs:  ["-11", "-11", "-11"]

Iteration:       3               Best score: 30          Best property: -1 == str_to_int_cvc(_arg_out)
Iteration:       3               Best cost:  0           Best outputs:  ["801-456-87651", "<978> 654-02991", "978.654.02991"]

Iteration:       4               Best score: 30          Best property: contains_cvc(int_to_str_cvc(len_cvc(_arg_out)), int_to_str_cvc(1))
Iteration:       4               Best cost:  0           Best outputs:  ["010 ", "010 ", "010 "]

Iteration:       5               Best score: 30          Best property: contains_cvc(int_to_str_cvc(len_cvc(_arg_out)), int_to_str_cvc(0))
Iteration:       5               Best cost:  1           Best outputs:  ["18010456087650", "1<978> 654002990", "19780654002990"]

Iteration:       6               Best score: 10          Best property: prefixof_cvc("<", _arg_out)
Iteration:       6               Best cost:  2           Best outputs:  ["8014568765", "<978> 6540299", "9786540299"]

Iteration:       7               Best score: 30          Best property: contains_cvc(_arg_out, int_to_str_cvc(0))
Iteration:       7               Best cost:  2           Best outputs:  ["1814568765", "1<978> 654299", "1978654299"]

Iteration:       8               Best score: 30          Best property: prefixof_cvc(int_to_str_cvc(0), _arg_out)
Iteration:       8               Best cost:  3           Best outputs:  ["0804568765", "0<978> 6540299", "0978065400299"]

Iteration:       9               Best score: 20          Best property: suffixof_cvc(int_to_str_cvc(0), int_to_str_cvc(len_cvc(_arg_out)))
Iteration:       9               Best cost:  3           Best outputs:  ["801045608765", "1978> 65400299", "9786540299"]

Iteration:       10              Best score: 20          Best property: prefixof_cvc(_arg_1, at_cvc(_arg_out, len_cvc(_arg_1)))
Iteration:       10              Best cost:  5           Best outputs:  ["801045608765", "1978> 65400299", "9786540299"]

Iteration:       11              Best score: 30          Best property: str_to_int_cvc(at_cvc(_arg_out, 1)) == 1
Iteration:       11              Best cost:  9           Best outputs:  [" 101", " 101", " 101"]

Solution found :)
replace_cvc(replace_cvc(replace_cvc(replace_cvc(replace_cvc(_arg_1, "-", ""), ".", ""), "<", ""), ">", ""), " ", "")
11{11{11{11{11{2,6,3},7,3},8,3},9,3},4,3}

=#