using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_phone_9_short
inputs = [io.in for io in problem.spec]
target_outputs = [io.out for io in problem.spec]
grammar = benchmark.grammar_phone_9_short
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]

addconstraint!(grammar, Contains(2))

#=

+106 769-858-438    ->    106.769.858.438
+6 775-969-238      ->    6.775.969.238

=#
properties = [
    (1, (x, y) -> length(y) >= 1 ? y[1] != "+" : false),
    (1, (x, y) -> length(y) >= 1 ? y[1] != x[:_arg_1][2] : false),
    (1, (x, y) -> count(==('.'), y) > 1 ),
    (1, (x, y) -> length(y) < 20),
]

function compute_priors()
    n = 0
    counts = fill(0, length(properties))

    for program in BFSIterator(grammar, :ntString, max_depth=2)
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

        diff = [w for (w, p) in properties if p(input, output) != p(input, target_output)]
        cost += sum(diff)
    end

    return cost
end

iterator = BeamIterator(grammar, :ntString,
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
        break
    end

    if i == 100
        break
    end
end