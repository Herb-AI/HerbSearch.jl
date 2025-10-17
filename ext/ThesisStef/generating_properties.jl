using HerbBenchmarks, HerbSearch, HerbConstraints, HerbCore, HerbGrammar
include("string_functions.jl")

grammar = HerbBenchmarks.PBE_SLIA_Track_2019.grammar_12948338
iterator = BFSIterator(grammar, :ntInt, max_depth=5)
addconstraint!(grammar, Contains(2))
# addconstraint!(grammar, Contains(3))

input = "Hello, World"
output = "Hello"
properties = 100

for (i, property) in enumerate(iterator)
    try
        tags = get_relevant_tags(grammar)

        tags[2] = input
        res_input = interpret_sygus(property, tags)

        tags[2] = output
        res_output = interpret_sygus(property, tags)

        if res_input != res_output
            @show property
            @show res_input
            @show res_output
            println()
        end

    catch e
        if e isa ArgumentError
            i += 1
            continue
        end
    end

    if i >= properties
        break
    end
end