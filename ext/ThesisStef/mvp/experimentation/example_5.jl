using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints
using DataStructures

include("../string_functions.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_count_total_words_in_a_cell
inputs = [io.in for io in problem.spec]
target_outputs = [io.out for io in problem.spec]
grammar = benchmark.grammar_count_total_words_in_a_cell
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]

addconstraint!(grammar, Contains(2))

#=

	IOExample(Dict{Symbol, Any}(:_arg_1 => "humpty dumpty"), 2), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "humpty dumpty sat on a wall,"), 6), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "couldnt put humpty together again."), 5)])

=#

properties = [
    (1, (x, y) -> y <= 6),
    (1, (x, y) -> y >= 2),
    (1, (x, y) -> y > count(==(' '), x[:_arg_1])),
    (1, (x, y) -> y == count(==(' '), x[:_arg_1]) + 1),
    (1, (x, y) -> y <= count(==(' '), x[:_arg_1]) + 1),
]

function compute_priors()
    n = 0
    counts = fill(0, length(properties))

    for program in BFSIterator(grammar, :ntInt, max_depth=2)
        outputs = interpreter(program)

        for (input, output) in zip(inputs, outputs)
            if isnothing(output)
                continue
            end

            n += 1
            counts += [p(input, output) for (w, p) in properties]
        end
    end

    @show counts / n
end

# compute_priors()

function heuristic(rulenode, child_values)
    outputs = rulenode._val

    cost = 0
    for (input, output, target_output) in zip(inputs, outputs, target_outputs)
        if isnothing(output)
            return Inf
        end

        diff = [p(input, output) == p(input, target_output) ? 0 : w for (w, p) in properties]
        cost += sum(diff)
    end

    return cost
end

function search()
    iterator = BeamIterator(grammar, :ntInt,
        beam_size = 10,
        program_to_cost = heuristic,
        max_extension_depth = 2,
        max_extension_size = 2,
        clear_beam_before_expansion = false,
        stop_expanding_beam_once_replaced = true,
        interpreter = interpreter,
        observation_equivalance = true,
    )

    for (i, entry) in enumerate(iterator)
        p = rulenode2expr(entry.program, grammar)
        c = entry.cost
        o = entry.program._val[1]

        println()
        @show i
        @show p
        @show c
        @show o

        if entry.program._val == target_outputs
            println("\nSolution found!")
            return
        end

        if i == 100
            break
        end
    end

    for entry in iterator.beam
        c = entry.cost
        o = entry.program._val
        @show c, o
    end
end

search()