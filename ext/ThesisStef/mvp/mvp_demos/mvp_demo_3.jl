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
)

#=

Without observational equivalance
-- Using only invariant properties works better for this problem... 

Iteration:       1               Best score: 40          Best property: prefixof_cvc(concat_cvc(_arg_1, " "), _arg_out)
Iteration:       1               Best cost:  0           Best outputs:  ["FreeHafer.", "Cencici.", "Kotas.", "Sergienko."]

Iteration:       2               Best score: 40          Best property: suffixof_cvc(at_cvc(_arg_2, len_cvc(_arg_out)), _arg_2)
Iteration:       2               Best cost:  0           Best outputs:  ["Nancy ", "Andrew ", "Jan ", "Mariya "]

Iteration:       3               Best score: 40          Best property: suffixof_cvc(concat_cvc(at_cvc(_arg_2, 1), "."), _arg_out)
Iteration:       3               Best cost:  0           Best outputs:  ["Nancy   ", "Andrew   ", "Jan   ", "Mariya   "]

Iteration:       4               Best score: 40          Best property: suffixof_cvc(concat_cvc(at_cvc(_arg_2, len_cvc(" ")), "."), _arg_out)
Iteration:       4               Best cost:  4           Best outputs:  ["Nancy   ", "Andrew   ", "Jan   ", "Mariya   "]

Iteration:       5               Best score: 40          Best property: suffixof_cvc(concat_cvc(at_cvc(_arg_2, len_cvc(".")), "."), _arg_out)
Iteration:       5               Best cost:  8           Best outputs:  ["Nancy   ", "Andrew   ", "Jan   ", "Mariya   "]

Iteration:       6               Best score: 40          Best property: suffixof_cvc(concat_cvc(substr_cvc(_arg_2, 1, 1), "."), _arg_out)
Iteration:       6               Best cost:  12          Best outputs:  ["Nancy   ", "Andrew   ", "Jan   ", "Mariya   "]

Iteration:       7               Best score: 30          Best property: prefixof_cvc(".", at_cvc(_arg_out, len_cvc(_arg_2)))
Iteration:       7               Best cost:  15          Best outputs:  ["Nancy Fre.", "Andrew .", "Jan K.", "Mariya Se."]

Iteration:       8               Best score: 40          Best property: suffixof_cvc(concat_cvc(" ", "."), _arg_out)
Iteration:       8               Best cost:  16          Best outputs:  ["Nancy  .", "Andrew  .", "Jan  .", "Mariya  ."]

Iteration:       9               Best score: 40          Best property: suffixof_cvc(" ", _arg_out)
Iteration:       9               Best cost:  18          Best outputs:  ["Nancy   ", "Andrew   ", "Jan   ", "Mariya   "]

Iteration:       10              Best score: 40          Best property: suffixof_cvc(concat_cvc(".", "."), _arg_out)
Iteration:       10              Best cost:  18          Best outputs:  ["Nancy ..", "Andrew ..", "Jan ..", "Mariya .."]

Iteration:       11              Best score: 30          Best property: suffixof_cvc(".", at_cvc(_arg_out, len_cvc(_arg_2)))
Iteration:       11              Best cost:  19          Best outputs:  ["Nancy Fre.", "Andrew .", "Jan K.", "Mariya Se."]

Iteration:       12              Best score: 40          Best property: suffixof_cvc(concat_cvc(" ", "."), concat_cvc(_arg_1, _arg_out))
Iteration:       12              Best cost:  20          Best outputs:  ["Nancy  .", "Andrew  .", "Jan  .", "Mariya  ."]

Iteration:       13              Best score: 30          Best property: prefixof_cvc(at_cvc(_arg_out, len_cvc(_arg_2)), ".")
Iteration:       13              Best cost:  23          Best outputs:  ["Nancy Fre.", "Andrew .", "Jan K.", "Mariya Se."]

Iteration:       14              Best score: 40          Best property: prefixof_cvc(_arg_1, _arg_out)
Iteration:       14              Best cost:  32          Best outputs:  ["FreeHafer", "Cencici", "Kotas", "Sergienko"]

Iteration:       15              Best score: 40          Best property: suffixof_cvc(_arg_1, _arg_out)
Iteration:       15              Best cost:  32          Best outputs:  ["NancyNancy", "AndrewAndrew", "JanJan", "MariyaMariya"]

Iteration:       16              Best score: 40          Best property: suffixof_cvc(concat_cvc(" ", "."), concat_cvc(_arg_2, _arg_out))
Iteration:       16              Best cost:  24          Best outputs:  ["Nancy  .", "Andrew  .", "Jan  .", "Mariya  ."]

Iteration:       17              Best score: 40          Best property: suffixof_cvc(".", _arg_out)
Iteration:       17              Best cost:  26          Best outputs:  ["Nancy   ", "Andrew   ", "Jan   ", "Mariya   "]

Iteration:       18              Best score: 40          Best property: len_cvc(_arg_2) == indexof_cvc(_arg_out, ".", 0)
Iteration:       18              Best cost:  26          Best outputs:  ["Nancy ..", "Andrew ..", "Jan ..", "Mariya .."]

Iteration:       19              Best score: 40          Best property: suffixof_cvc(concat_cvc(" ", "."), concat_cvc(" ", _arg_out))
Iteration:       19              Best cost:  28          Best outputs:  ["Nancy  .", "Andrew  .", "Jan  .", "Mariya  ."]

Iteration:       20              Best score: 40          Best property: suffixof_cvc(at_cvc(_arg_out, len_cvc(_arg_2)), _arg_2)
Iteration:       20              Best cost:  38          Best outputs:  ["Nancy.", "Andrew.", "Jan.", "Mariya."]

Solution found :)
concat_cvc(_arg_1, concat_cvc(" ", replace_cvc(_arg_2, substr_cvc(_arg_2, 2, len_cvc(_arg_2)), ".")))
6{2,6{4,7{3,9{3,12,15{3}},5}}}
=#