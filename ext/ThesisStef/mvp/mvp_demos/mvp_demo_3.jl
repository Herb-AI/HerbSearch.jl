using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("../properties.jl")
include("../search.jl")

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
property_interpreter = (p, y) -> [interpret_sygus(p, property_grammar_tags, (input[:_arg_out] = y; input)) for input in inputs]

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
    max_iterations = 100,
    max_extension_depth = 3,
    max_extension_size = 6,
)

#=

Problem: it still falls into a local optima, as it increases many of the costs
=#