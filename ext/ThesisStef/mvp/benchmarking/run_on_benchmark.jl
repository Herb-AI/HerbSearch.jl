using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints
using JSON

include("../string_functions.jl")
include("../properties.jl")
include("../search_alt.jl")


function test_problem(benchmark, benchmark_name, problem, problem_name, grammar)
    inputs = [io.in for io in problem.spec]
    grammar_tags = benchmark.get_relevant_tags(grammar)
    interpreter = p -> [interpret_sygus(p, grammar_tags, input) for input in inputs]
    starting_symbol = grammar.rules[1]

    println("\n\nProblem $problem_name")
    for io in problem.spec
        @show io
    end

    property_grammar = deepcopy(grammar)
    merge_grammars!(property_grammar, @cfgrammar begin
        ntInt = 1 | 2 | 3 | 4 | 5 | 6
        ntBool = ntString == ntString
        ntBool = ntInt == ntInt
        ntBool = ntInt <= ntInt
        ntBool = ntInt < ntInt
    end)
    add_rule!(property_grammar, Expr(:(=), starting_symbol, :_arg_out))
    addconstraint!(property_grammar, Contains(length(property_grammar.rules)))
    property_grammar_tags = benchmark.get_relevant_tags(property_grammar)
    property_interpreter = (p, ys) -> [interpret_sygus(p, property_grammar_tags, (input[:_arg_out] = y; input)) for (input, y) in zip(inputs, ys)]

    properties = generate_properties(;
        grammar = property_grammar,
        property_symbol = :ntBool,
        interpreter = property_interpreter,
        max_depth = 5,#4,
        max_size = 7,#6,
    )

    @show length(properties)

    program, heuristic_properties = search(
        problem = problem,
        grammar = grammar,
        interpreter = interpreter,
        properties = properties,
        starting_symbol = starting_symbol,
        beam_size = 10,
        max_iterations = 100,
        max_extension_depth = 2,
        max_extension_size = 4,
        observation_equivalance = true,
    )

    solved = !isnothing(program)
    
    results = [
        "problem" => problem,
        "solved" => solved,
        "program" => solved ? string(rulenode2expr(program, grammar)) : "nothing",
        "properties" => [string(p) for p in heuristic_properties],
    ]

    filename = "ext/ThesisStef/mvp/benchmarking/results/$benchmark_name.json"
    data = isfile(filename) ? JSON.parsefile(filename) : Any[]
    push!(data, results)

    open(filename, "w") do io
        JSON.print(io, data, 4)
    end
end

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
benchmark_name = "SyGuS_strings"

problem_names = [String(s)[9:end] for s in names(benchmark; all=false) if startswith(String(s), "problem_")]
# problem_names = problem_names[1:100]
problem_names = problem_names[2:2]

for n in problem_names
    problem  = getfield(benchmark, Symbol("problem_", n))
    grammar  = getfield(benchmark, Symbol("grammar_", n))
    test_problem(benchmark, benchmark_name, problem, n, grammar)
end

