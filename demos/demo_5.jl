using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("string_functions.jl")
include("run_on_problem.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019

run( 
    benchmark = HerbBenchmarks.PBE_SLIA_Track_2019,
    benchmark_name = "SyGuS string",
    problem = benchmark.problem_initials_small,
    grammar = benchmark.grammar_initials_small,
    max_property_depth = 5,
    max_property_size = 8,
)

#=

Problem problem_initials_small
Dict{Symbol, Any}(:_arg_1 => "Nancy FreeHafer", :_arg_out => "N.F.") -> N.F.
Dict{Symbol, Any}(:_arg_1 => "Andrew Cencici", :_arg_out => "A.C.") -> A.C.
Dict{Symbol, Any}(:_arg_1 => "Jan Kotas", :_arg_out => "J.K.") -> J.K.
Dict{Symbol, Any}(:_arg_1 => "Mariya Sergienko", :_arg_out => "M.S.") -> M.S.

Solution found in 85 iterations!
expr = :(concat_cvc(concat_cvc(at_cvc(_arg_1, 1), "."), concat_cvc(at_cvc(_arg_1, indexof_cvc(_arg_1, " ", 2) + 1), ".")))

With 6 properties:
 - prefixof_cvc(at_cvc(_arg_out, 2), ".")
 - 2 + 2 == len_cvc(_arg_out)
 - prefixof_cvc(at_cvc(_arg_1, 1), _arg_out)
 - suffixof_cvc(concat_cvc(" ", " "), replace_cvc(_arg_out, ".", " "))
 - suffixof_cvc(".", replace_cvc(_arg_out, concat_cvc(" ", "."), _arg_1))
 - suffixof_cvc(substr_cvc(_arg_out, 1, 2), _arg_out)

 
=#