using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("string_functions.jl")
include("run_on_problem.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019

run( 
    benchmark = HerbBenchmarks.PBE_SLIA_Track_2019,
    benchmark_name = "SyGuS string",
    problem = benchmark.problem_phone_9_short,
    grammar = benchmark.grammar_phone_9_short,
)

#=

Problem problem_phone_9_short
Dict{Symbol, Any}(:_arg_1 => "+106 769-858-438", :_arg_out => "106.769.858.438") -> 106.769.858.438
Dict{Symbol, Any}(:_arg_1 => "+83 973-757-831", :_arg_out => "83.973.757.831") -> 83.973.757.831
Dict{Symbol, Any}(:_arg_1 => "+62 647-787-775", :_arg_out => "62.647.787.775") -> 62.647.787.775
Dict{Symbol, Any}(:_arg_1 => "+172 027-507-632", :_arg_out => "172.027.507.632") -> 172.027.507.632
Dict{Symbol, Any}(:_arg_1 => "+72 001-050-856", :_arg_out => "72.001.050.856") -> 72.001.050.856
Dict{Symbol, Any}(:_arg_1 => "+95 310-537-401", :_arg_out => "95.310.537.401") -> 95.310.537.401
Dict{Symbol, Any}(:_arg_1 => "+6 775-969-238", :_arg_out => "6.775.969.238") -> 6.775.969.238

Solution found in 99 iterations!
expr = :(replace_cvc(substr_cvc(replace_cvc(_arg_1, "-", "."), 2, len_cvc(_arg_1)), " ", "."))

With 5 properties:
 - prefixof_cvc(substr_cvc(_arg_out, 1, 2), _arg_1)
 - prefixof_cvc(at_cvc(_arg_1, 2), _arg_out)
 - contains_cvc(substr_cvc(_arg_out, 1, 4), ".")
 - contains_cvc(replace_cvc(_arg_out, " ", _arg_1), "+")
 - len_cvc(_arg_out) <= 5

=#