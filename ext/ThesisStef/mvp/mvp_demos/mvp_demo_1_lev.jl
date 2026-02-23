using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("lev.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_phone_9_short
inputs = [io.in for io in problem.spec]
target_outputs = [io.out for io in problem.spec]
grammar = benchmark.grammar_phone_9_short
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]

function heuristic(program, children)
    outputs = interpreter(program)

    if any(isnothing, outputs)
        return Inf
    end

    return sum([ls(output, target) for (output, target) in zip(outputs, target_outputs)])
end

iterator = BeamIterator(grammar, :ntString,
    beam_size = 10,
    program_to_cost = heuristic,
    max_extension_depth = 2,
    max_extension_size = 2,
    clear_beam_before_expansion = false,
    stop_expanding_beam_once_replaced = false,
    interpreter = interpreter,
    observation_equivalance = true,
)

#=

	IOExample(Dict{Symbol, Any}(:_arg_1 => "+106 769-858-438"), "106.769.858.438"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+83 973-757-831"), "83.973.757.831"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+62 647-787-775"), "62.647.787.775"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+172 027-507-632"), "172.027.507.632"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+72 001-050-856"), "72.001.050.856"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+95 310-537-401"), "95.310.537.401"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "+6 775-969-238"), "6.775.969.238")])

=#

for (i, e) in enumerate(iterator)
    @show i
    @show e.program
    @show e.program._val

    if e.program._val == target_outputs
        println("\nSolution found!")

        break
    end

    if i % 50 == 0
        break
    end
end