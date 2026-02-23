using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("lev.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_phone_1_short
inputs = [io.in for io in problem.spec]
target_outputs = [io.out for io in problem.spec]
grammar = benchmark.grammar_phone_1_short
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

	IOExample(Dict{Symbol, Any}(:_arg_1 => "938-242-504"), "242"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "308-916-545"), "916"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "623-599-749"), "599"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "981-424-843"), "424"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "118-980-214"), "980"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "244-655-094"), "655")])

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