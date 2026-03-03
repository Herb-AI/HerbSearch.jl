using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("string_functions.jl")
include("run_on_problem.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019

run( 
    benchmark = HerbBenchmarks.PBE_SLIA_Track_2019,
    benchmark_name = "SyGuS string",
    problem = benchmark.problem_name_combine_2,
    grammar = benchmark.grammar_name_combine_2,
)

#=

Problem problem_name_combine_2
Dict{Symbol, Any}(:_arg_1 => "Nancy", :_arg_2 => "FreeHafer", :_arg_out => "Nancy F.") -> Nancy F.
Dict{Symbol, Any}(:_arg_1 => "Andrew", :_arg_2 => "Cencici", :_arg_out => "Andrew C.") -> Andrew C.
Dict{Symbol, Any}(:_arg_1 => "Jan", :_arg_2 => "Kotas", :_arg_out => "Jan K.") -> Jan K.
Dict{Symbol, Any}(:_arg_1 => "Mariya", :_arg_2 => "Sergienko", :_arg_out => "Mariya S.") -> Mariya S.

Solution found in 31 iterations!
expr = :(concat_cvc(concat_cvc(_arg_1, " "), concat_cvc(at_cvc(_arg_2, 1), ".")))

With 2 properties:
 - suffixof_cvc(_arg_out, replace_cvc(_arg_out, " ", _arg_out))
 - indexof_cvc(_arg_out, ".", 0) <= 2

=#