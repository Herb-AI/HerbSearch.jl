using HerbCore, HerbGrammar, HerbConstraints, HerbBenchmarks, HerbSearch, HerbSpecification
using Profile, ProfileView

# Profile.clear()

include("property_generation.jl")
include("string_functions.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019

# ("+106 769-858-438") -> "106.769.858.438"
# problem = benchmark.problem_phone_9_short
# grammar = benchmark.grammar_phone_9_short
# output_type = :ntString

# ("Trucking Inc.") -> "Trucking Inc."
# ("ABV Trucking Inc, LLC"), "ABV Trucking"
# problem = benchmark.problem_stackoverflow1
# grammar = benchmark.grammar_stackoverflow1
# output_type = :ntString

# ("I love apples", "I hate bananas", "banana") -> "I hate bananas"
# ("I love apples", "I hate bananas", "apple")  -> "I love apples"
problem = benchmark.problem_37534494
grammar = benchmark.grammar_37534494
output_type = :ntString

# Count occurrences of _arg_2 in _arg_1
# problem = benchmark.problem_12948338
# grammar = benchmark.grammar_12948338
# output_type = :ntInt


target_outputs = [e.out for e in problem.spec]
inputs = [e.in for e in problem.spec]

grammar_extension = @cfgrammar begin
    ntInt = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20
    ntBool = ntInt == ntInt
    # ntBool = ntInt != ntInt
    ntBool = ntInt < ntInt
    ntBool = ntInt > ntInt
    # ntBool = !ntBool
    ntBool = and(ntBool, ntBool)
    ntBool = or(ntBool, ntBool)
    ntBool = ntBool == ntBool
    # ntBool = ntBool != ntBool
    ntBool = ntString == ntString
    # ntBool = ntString != ntString
end

# Create property grammar before alterations
property_grammar = deepcopy(grammar)
merge_grammars!(property_grammar, grammar_extension)

properties = generate_properties(
    grammar = grammar,
    property_grammar = property_grammar,
    interpreter = interpret_sygus,
    inputs = inputs,
    target_outputs = target_outputs,
    output_type = output_type,
    boolean_type = :ntBool,
    max_property_size = 4,
    max_program_size = 3,
    max_number_of_properties = 1,
    ideal_prune_ratio = 1,
)

for p in properties
    expr = rulenode2expr(p, property_grammar)
    @show expr
end

satisfying_programs = find_programs_satisfying_properties(;
    grammar = grammar,
    property_grammar = property_grammar,
    properties = properties,
    interpreter = interpret_sygus,
    output_type = output_type,
    max_program_size = 3,
)


for p in satisfying_programs
    prog = rulenode2expr(p, grammar)
    @show prog
end