using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")
include("lev.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_name_combine_2
inputs = [io.in for io in problem.spec]
target_outputs = [io.out for io in problem.spec]
grammar = benchmark.grammar_name_combine_2
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

	IOExample(Dict{Symbol, Any}(:_arg_1 => "Nancy", :_arg_2 => "FreeHafer"), "Nancy F."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Andrew", :_arg_2 => "Cencici"), "Andrew C."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Jan", :_arg_2 => "Kotas"), "Jan K."), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "Mariya", :_arg_2 => "Sergienko"), "Mariya S.")])


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