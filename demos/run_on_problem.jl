function run(;
    benchmark,
    benchmark_name,
    interpeter,
    problem,
    full_problem,
    grammar,
    starting_symbol = nothing,
    property_grammar_extension,
    property_symbol,
    pool_size = 10,
    max_extension_depth = 1,
    max_extension_size = 1,
    max_property_depth = 4,
    max_property_size = 6,
    max_number_of_properties = 50,
    max_iterations = 10000,
)
    starting_symbol = isnothing(starting_symbol) ? grammar.rules[1] : starting_symbol
    property_grammar = deepcopy(grammar)
    merge_grammars!(property_grammar, property_grammar_extension)
    add_rule!(property_grammar, Expr(:(=), starting_symbol, :_arg_out))
    addconstraint!(property_grammar, Contains(length(property_grammar.rules)))
    grammar_tags = get_relevant_tags(property_grammar)

    properties = Vector{AbstractRuleNode}(collect(BFSIterator(property_grammar, property_symbol, 
        max_depth = max_property_depth, 
        max_size = max_property_size,
    )))

    iterator = PropertyBasedNeighborhoodIterator(grammar, starting_symbol,
        problem,
        (p, x) -> interpret_sygus(p, grammar_tags, x),
        pool_size,
        properties,

        max_extension_depth = max_extension_depth,
        max_extension_size = max_extension_size,

        property_grammar = property_grammar,

        max_number_of_properties = max_number_of_properties,
    )

    iterations = nothing
    solution = nothing
    full_problem_acc = nothing

    function print_parents(pool_entry)
        if !isnothing(pool_entry.parent)
            (p, i) = pool_entry.parent
            e = rulenode2expr(p.program, grammar)
            c = p.cost
            println("$i\t$c\t$e")
            print_parents(p)
        end
    end

    for (i, program) in enumerate(iterator)
        cost = heuristic_cost(iterator, program)
        expr = rulenode2expr(program, grammar)
        pool_entry = iterator.pool[findfirst(e -> e.program == program, iterator.pool)]
        
        println()
        @show i
        @show expr
        @show program._val
        @show cost
        print_parents(pool_entry)


        if program._val == [io.out for io in problem.spec]
            iterations = i
            solution = program
            break
        end

        if i == max_iterations
            iterations = i
            break
        end
    end

    println("\nProblem $(problem.name)")
    for io in problem.spec
        println("$(io.in) -> $(io.out)")
    end

    if isnothing(solution)
        println("\nReached max iterations or properties")
    else
        println("\nSolution found in $iterations iterations!")
        expr = rulenode2expr(solution, grammar)
        @show expr

        full_problem_acc = count(interpeter(solution, grammar_tags, io.in) == io.out for io in full_problem.spec)
        println("Solved $full_problem_acc / $(length(full_problem.spec)) (trained on $(length(problem.spec)))")
    end

    println("\nWith $(length(iterator.selected_properties)) properties:")
    for property in iterator.selected_properties
        prop = rulenode2expr(property, property_grammar)
        println(" - $prop")
    end

    return Dict(
        "benchmark_name" => benchmark_name,
        "problem" => problem,
        "problem_accuracy" => "Solved $full_problem_acc / $(length(full_problem.spec)) (trained on $(length(problem.spec)))",
        "solved" => !isnothing(solution),
        "iterations" => iterations,
        "program" => !isnothing(solution) ? string(rulenode2expr(solution, grammar)) : "nothing",
        "properties" => [string(rulenode2expr(p, property_grammar)) for p in iterator.selected_properties],
    )
end

function save(results)
    benchmark_name = results["benchmark_name"]
    filename = "demos/results/$benchmark_name.json"
    data = isfile(filename) ? JSON.parsefile(filename) : Any[]
    push!(data, results)

    open(filename, "w") do io
        JSON.print(io, data, 4)
    end
end
