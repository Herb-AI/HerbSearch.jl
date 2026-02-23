using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../properties.jl")
include("../search_alt.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_initials_small
inputs = [io.in for io in problem.spec]
grammar = benchmark.grammar_initials_small
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]

property_grammar = deepcopy(grammar)
merge_grammars!(property_grammar, @cfgrammar begin
    ntInt = 1 | 2 | 3 | 4
    ntBool = ntString == ntString
    ntBool = ntInt == ntInt
    ntString = _arg_out
end)
addconstraint!(property_grammar, Contains(length(property_grammar.rules)))
property_grammar_tags = benchmark.get_relevant_tags(property_grammar)
property_interpreter = (p, y) -> [interpret_sygus(p, property_grammar_tags, (input[:_arg_out] = y; input)) for input in inputs]

#=

	IOExample(Dict{Symbol, Any}(:_arg_1 => "Nancy FreeHafer"), "N.F."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Andrew Cencici"), "A.C."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Jan Kotas"), "J.K."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Mariya Sergienko"), "M.S.")])


This needs really large beam extensions, so running might take a while...

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
    interpreter = interpreter,
    properties = properties,
    max_iterations = 20,
    max_extension_depth = 2,
    max_extension_size = 4,
    observation_equivalance = true,
)

#=

With observational equivalance

Iteration:       1               Best score: 40          Best property: len_cvc(_arg_out) == 4
Iteration:       1               Best cost:  0           Best outputs:  ["  ", "  ", "  ", "  "]

Iteration:       2               Best score: 40          Best property: 4 == len_cvc(_arg_out)
Iteration:       2               Best cost:  4           Best outputs:  ["  ", "  ", "  ", "  "]

Iteration:       3               Best score: 40          Best property: prefixof_cvc(at_cvc(_arg_out, 2), ".")
Iteration:       3               Best cost:  8           Best outputs:  ["  ", "  ", "  ", "  "]

Iteration:       4               Best score: 40          Best property: prefixof_cvc(at_cvc(_arg_1, 1), _arg_out)
Iteration:       4               Best cost:  0           Best outputs:  ["..Na", "..An", "..Ja", "..Ma"]

Iteration:       5               Best score: 32          Best property: suffixof_cvc(".", _arg_out)
Iteration:       5               Best cost:  0           Best outputs:  ["N.a ", "A.n ", "J.a ", "M.a "]

Iteration:       6               Best score: 11          Best property: suffixof_cvc(at_cvc(_arg_out, 3), _arg_1)
Iteration:       6               Best cost:  0           Best outputs:  ["N.y.", "A.e.", "J.K.", "M.y."]

Solution found :)
concat_cvc(concat_cvc(concat_cvc(at_cvc(_arg_1, 1), "."), at_cvc(_arg_1, 1 + indexof_cvc(_arg_1, " ", 0))), ".")
5{5{5{7{2,10},4},7{2,12{10,15{2,3,9}}}},4}


=#