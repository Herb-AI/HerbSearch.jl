using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("string_functions.jl")
include("run_on_problem.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019

run( 
    benchmark = HerbBenchmarks.PBE_SLIA_Track_2019,
    benchmark_name = "SyGuS string",
    problem = benchmark.problem_clean_and_reformat_telephone_numbers,
    grammar = benchmark.grammar_clean_and_reformat_telephone_numbers,
)

#=

Problem problem_clean_and_reformat_telephone_numbers
Dict{Symbol, Any}(:_arg_1 => "801-456-8765", :_arg_out => "8014568765") -> 8014568765
Dict{Symbol, Any}(:_arg_1 => "<978> 654-0299", :_arg_out => "9786540299") -> 9786540299
Dict{Symbol, Any}(:_arg_1 => "978.654.0299", :_arg_out => "9786540299") -> 9786540299

Solution found in 190 iterations!
expr = :(replace_cvc(replace_cvc(replace_cvc(replace_cvc(replace_cvc(_arg_1, ".", "-"), "-", ""), concat_cvc(">", " "), "."), "<", "."), ".", ""))

With 7 properties:
 - 1 < str_to_int_cvc(_arg_out)
 - contains_cvc(_arg_1, _arg_out)
 - contains_cvc(int_to_str_cvc(len_cvc(_arg_out)), int_to_str_cvc(1))
 - contains_cvc(int_to_str_cvc(len_cvc(_arg_out)), int_to_str_cvc(0))
 - contains_cvc(_arg_out, " ")
 - prefixof_cvc("<", _arg_out)
 - contains_cvc(_arg_out, ">")
 
=#