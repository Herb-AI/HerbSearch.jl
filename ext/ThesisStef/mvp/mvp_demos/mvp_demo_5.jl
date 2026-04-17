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
starting_symbol = grammar.rules[1]

property_grammar = deepcopy(grammar)
merge_grammars!(property_grammar, @cfgrammar begin
    ntInt = 1 | 2 | 3 | 4
    ntBool = ntString == ntString
    ntBool = ntInt == ntInt
    ntString = _arg_out
end)
addconstraint!(property_grammar, Contains(length(property_grammar.rules)))
property_grammar_tags = benchmark.get_relevant_tags(property_grammar)
property_interpreter = (p, ys) -> [interpret_sygus(p, property_grammar_tags, (input[:_arg_out] = y; input)) for (y, input) in zip(ys, inputs)]

#=

	IOExample(Dict{Symbol, Any}(:_arg_1 => "Nancy FreeHafer"), "N.F."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Andrew Cencici"), "A.C."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Jan Kotas"), "J.K."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Mariya Sergienko"), "M.S.")])

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

Iteration:       1               Best score: 40/40               Best property: 4 == len_cvc(_arg_out)
Best outputs     ["Nancy FreeHafer", "Andrew Cencici", "Jan Kotas", "Mariya Sergienko"]
Best cost        0

Iteration:       2               Best score: 40/40               Best property: len_cvc(_arg_out) == 4
Best outputs     ["Nancy FreeHafer", "Andrew Cencici", "Jan Kotas", "Mariya Sergienko"]
Best cost        4

Iteration:       3               Best score: 40/40               Best property: prefixof_cvc(".", at_cvc(_arg_out, 2))
Best outputs     ["Nancy FreeHafer", "Andrew Cencici", "Jan Kotas", "Mariya Sergienko"]
Best cost        8

Iteration:       4               Best score: 40/40               Best property: prefixof_cvc(at_cvc(_arg_1, 1), _arg_out)
Best outputs     [" ...", " ...", " ...", " ..."]
Best cost        0

Iteration:       5               Best score: 39/40               Best property: suffixof_cvc(".", _arg_out)
Best outputs     ["N.nc", "A.dr", "J.n ", "M.ri"]
Best cost        0

Iteration:       6               Best score: 16/40               Best property: prefixof_cvc(" ", at_cvc(_arg_out, 3))
Best outputs     ["N. .", "A. .", "J. .", "M. ."]
Best cost        0

Iteration:       7               Best score: 20/40               Best property: prefixof_cvc(".", at_cvc(_arg_out, 3))
Best outputs     ["N...", "A...", "J...", "M..."]
Best cost        0

Iteration:       8               Best score: 20/40               Best property: prefixof_cvc(at_cvc(_arg_out, 3), _arg_1)
Best outputs     ["N.N.", "A.A.", "J.J.", "M.M."]
Best cost        0

Iteration:       9               Best score: 36/40               Best property: prefixof_cvc(at_cvc(_arg_1, 2), at_cvc(_arg_out, 3))
Best outputs     ["N.a.", "A.n.", "J.a.", "M.a."]
Best cost        0

Iteration:       10              Best score: 20/39               Best property: suffixof_cvc(at_cvc(_arg_out, 3), _arg_1)
Best outputs     ["N.r.", "A.i.", "J.s.", "M.o."]
Best cost        0

Solution found :)
concat_cvc(concat_cvc(at_cvc(_arg_1, 1), "."), concat_cvc(at_cvc(_arg_1, indexof_cvc(_arg_1, " ", 0) + 1), "."))


=#