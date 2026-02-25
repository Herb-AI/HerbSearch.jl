using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints
using Profile, ProfileView

include("string_functions.jl")

Profile.clear()

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_phone_9_short
grammar = benchmark.grammar_phone_9_short
starting_symbol = :ntString

property_grammar = deepcopy(grammar)
merge_grammars!(property_grammar, @cfgrammar begin
    ntBool = ntString == ntString
    ntBool = ntInt == ntInt
    ntBool = ntInt <= ntInt
    ntBool = ntInt < ntInt
    # ntBool = and(ntBool, ntBool)
    # ntBool = or(ntBool, ntBool)
    # ntBool = xor(ntBool, ntBool)
    # ntBool = implies(ntBool, ntBool)
    ntString = _arg_out
end)
addconstraint!(property_grammar, Contains(length(property_grammar.rules)))
grammar_tags = benchmark.get_relevant_tags(property_grammar)

properties = Vector{AbstractRuleNode}(collect(BFSIterator(property_grammar, :ntBool, 
    max_depth = 3, 
    max_size = 5,
)))

iterator = PropertyBasedNeighborhoodIterator(grammar, starting_symbol,
    problem,
    (p, x) -> interpret_sygus(p, grammar_tags, x),
    10,
    properties,

    max_extension_depth = 2,
    max_extension_size = 4,

    property_grammar = property_grammar,

    max_number_of_properties = 6,
)

for io in problem.spec
    println("$(io.in) -> $(io.out)")
end


@profile begin
    for (i, program) in enumerate(iterator)
        cost = heuristic_cost(iterator, program)
        expr = rulenode2expr(program, grammar)
        
        # println()
        @show i
        # @show expr
        # @show program._val
        # @show cost

        if program._val == [io.out for io in problem.spec]
            println("\nSolution found in $i iterations!")
            expr = rulenode2expr(program, grammar)
            @show expr

            println("\nWith $(length(iterator.selected_properties)) properties:")
            for property in iterator.selected_properties
                prop = rulenode2expr(property, property_grammar)
                println(" - $prop")
            end

            break
        end

        if i == 30
            println("Reached max iterations")
            break
        end
    end
end

ProfileView.view()

#=


=#