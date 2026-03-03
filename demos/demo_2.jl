using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("string_functions.jl")
include("run_on_problem.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019

run( 
    benchmark = HerbBenchmarks.PBE_SLIA_Track_2019,
    benchmark_name = "SyGuS string",
    problem = benchmark.problem_phone_1_short,
    grammar = benchmark.grammar_phone_1_short,
)

#=

Problem problem_phone_1_short
Dict{Symbol, Any}(:_arg_1 => "938-242-504", :_arg_out => "242") -> 242
Dict{Symbol, Any}(:_arg_1 => "308-916-545", :_arg_out => "916") -> 916
Dict{Symbol, Any}(:_arg_1 => "623-599-749", :_arg_out => "599") -> 599
Dict{Symbol, Any}(:_arg_1 => "981-424-843", :_arg_out => "424") -> 424
Dict{Symbol, Any}(:_arg_1 => "118-980-214", :_arg_out => "980") -> 980
Dict{Symbol, Any}(:_arg_1 => "244-655-094", :_arg_out => "655") -> 655

Solution found in 108 iterations!
expr = :(substr_cvc(_arg_1, 5, 5 + 2))

With 4 properties:
 - len_cvc(_arg_out) == 3
 - prefixof_cvc(at_cvc(_arg_1, 5), _arg_out)
 - contains_cvc(_arg_1, _arg_out)
 - contains_cvc(_arg_out, at_cvc(_arg_1, 4))
 
 =#