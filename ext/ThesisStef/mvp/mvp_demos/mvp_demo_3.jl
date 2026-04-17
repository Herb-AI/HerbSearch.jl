using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../properties.jl")
include("../search_alt.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_name_combine_2
inputs = [io.in for io in problem.spec]
grammar = benchmark.grammar_name_combine_2
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

	IOExample(Dict{Symbol, Any}(:_arg_1 => "Nancy", :_arg_2 => "FreeHafer"), "Nancy F."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Andrew", :_arg_2 => "Cencici"), "Andrew C."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Jan", :_arg_2 => "Kotas"), "Jan K."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Mariya", :_arg_2 => "Sergienko"), "Mariya S.")])

=#


#=

We need this property, but is extermely complex (depth 5, size 8)
    startswith(
        :_arg_2, 
        at_cvc(
            _out, 
            -
                len(
                    _out
                )
                1
    ))

=#

properties = generate_properties(;
    grammar = property_grammar,
    property_symbol = :ntBool,
    interpreter = property_interpreter,
	max_depth = 5,
	max_size = 8,
)

@show length(properties)

search(
    problem = problem,
    grammar = grammar,
    interpreter = interpreter,
    properties = properties,
    max_iterations = 50,
    max_extension_depth = 2,
    max_extension_size = 4,
    observation_equivalance = true,
)

#=

Iteration:       1               Best score: 40/40               Best property: suffixof_cvc(_arg_out, replace_cvc(_arg_out, " ", _arg_out))
Best outputs     ["Nancy", "Andrew", "Jan", "Mariya"]
Best cost        0

Iteration:       2               Best score: 40/40               Best property: prefixof_cvc(_arg_1, _arg_out)
Best outputs     [" Nancy", " Andrew", " Jan", " Mariya"]
Best cost        0

Iteration:       3               Best score: 40/40               Best property: suffixof_cvc(concat_cvc(at_cvc(_arg_2, 1), "."), _arg_out)
Best outputs     ["Nancy FreeHafer", "Andrew Cencici", "Jan Kotas", "Mariya Sergienko"]
Best cost        0

Iteration:       4               Best score: 40/40               Best property: suffixof_cvc(concat_cvc(at_cvc(_arg_2, len_cvc(" ")), "."), _arg_out)
Best outputs     ["Nancy FreeHafer", "Andrew Cencici", "Jan Kotas", "Mariya Sergienko"]
Best cost        4

Solution found :)
concat_cvc(concat_cvc(_arg_1, " "), concat_cvc(at_cvc(_arg_2, 1), "."))

=#