using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("../string_functions.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_clean_and_reformat_telephone_numbers
inputs = [io.in for io in problem.spec]
target_outputs = [io.out for io in problem.spec]
grammar = benchmark.grammar_clean_and_reformat_telephone_numbers
grammar_tags = benchmark.get_relevant_tags(grammar)
interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]

addconstraint!(grammar, Contains(2))

#=

	IOExample(Dict{Symbol, Any}(:_arg_1 => "801-456-8765"), "8014568765"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "<978> 654-0299"), "9786540299"), 
	IOExample(Dict{Symbol, Any}(:_arg_1 => "978.654.0299"), "9786540299")])

=#

properties = [
    (1, (x, y) -> length(y) < length(x[:_arg_1])),
    (1, (x, y) -> length(y) > 1),
    (1, (x, y) -> length(y) > 2),
    (1, (x, y) -> !occursin("-", y)),
    (1, (x, y) -> !occursin("<", y)),
    (1, (x, y) -> !occursin(">", y)),
    (1, (x, y) -> !occursin(" ", y)),
    (1, (x, y) -> !occursin(".", y)),
    (1, (x, y) -> !occursin(",", y)),
    (1, (x, y) -> length(y) <= length(x[:_arg_1]) - 2),
    (1, (x, y) -> length(y) > 6),
    # (1, (x, y) -> length(y) >= length(x[:_arg_1]) - 4),
    # (1, (x, y) -> length(y) >= 1 ? y[1] != '0' : false),
    # (1, (x, y) -> length(y) >= 1 ? y[1] != '1' : false),
]

#=

    Problem: the cost of substituting a forbidden symbol for "" is the same as doing it with "0"
    There is not a property that prevents this. Maybe if the grammar has a "count_occurences" function it might be possible.

=#

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

        diff = [p(input, output) == p(input, target_output) ? 0 : w for (w, p) in properties]
        cost += sum(diff)
    end

    return cost
end

function search()
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

    counter_examples = []

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

        if c == 0
            push!(counter_examples, entry.program._val)
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