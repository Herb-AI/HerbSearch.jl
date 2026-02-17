using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("string_functions.jl")

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
    (1, (x, y) -> !occursin("-", y)),
    (1, (x, y) -> !occursin("<", y)),
    (1, (x, y) -> !occursin(">", y)),
    (1, (x, y) -> !occursin(" ", y)),
    (1, (x, y) -> !occursin(".", y)),
    (1, (x, y) -> !occursin(",", y)),
    (1, (x, y) -> length(y) >= 10),
    (1, (x, y) -> length(y) < length(x[:_arg_1]) - 1),
    # (1, (x, y) -> count(==('0'), y) == count(==('0'), x[:_arg_1])),
    # (1, (x, y) -> count(==('1'), y) == count(==('1'), x[:_arg_1])),
    # (1, (x, y) -> count(==('2'), y) == count(==('2'), x[:_arg_1])),
    # (1, (x, y) -> count(==('3'), y) == count(==('3'), x[:_arg_1])),
    # (1, (x, y) -> count(==('4'), y) == count(==('4'), x[:_arg_1])),
    # (1, (x, y) -> count(==('5'), y) == count(==('5'), x[:_arg_1])),
    # (1, (x, y) -> count(==('6'), y) == count(==('6'), x[:_arg_1])),
    # (1, (x, y) -> count(==('7'), y) == count(==('7'), x[:_arg_1])),
    # (1, (x, y) -> count(==('8'), y) == count(==('8'), x[:_arg_1])),
    # (1, (x, y) -> count(==('9'), y) == count(==('9'), x[:_arg_1])),
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

function search()
    iterator = BeamIterator(grammar, :ntString,
        beam_size = 10,
        program_to_cost = heuristic,
        max_extension_depth = 1,
        max_extension_size = 1,
        clear_beam_before_expansion = false,
        stop_expanding_beam_once_replaced = true,
        interpreter = interpreter,
        observation_equivalance = true,
    )

    counts = fill(0, length(properties))
    n = 0

    for (i, entry) in enumerate(iterator)
        p = rulenode2expr(entry.program, grammar)
        c = entry.cost
        o = entry.program._val#[1]

        println()
        @show i
        @show p
        @show c
        @show o

        for (input, output) in zip(inputs, o)
            n += 1
            counts += [p(input, output) for (w, p) in properties]
        end

        if entry.program._val == target_outputs
            println("\nSolution found!")
            break
        end

        if i == 100
            break
        end
    end

    @show (counts / n)
    return nothing
end

# compute_priors()
search()