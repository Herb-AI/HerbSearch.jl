using HerbCore, HerbGrammar, HerbConstraints, HerbBenchmarks, HerbSearch, HerbSpecification
using Statistics, LinearAlgebra
include("data_generation.jl")
include("string_functions.jl")
include("generating_properties.jl")
include("property_signature.jl")


benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
grammar = benchmark.grammar_11604909
problem = benchmark.problem_11604909
target = [e.out for e in problem.spec]

grammar_extension = @cfgrammar begin
    ntInt = 0
    ntInt = 1
    ntInt = 2
    ntInt = 3
    ntInt = 4
    ntInt = 5
    ntBool = ntInt != ntInt
    ntBool = ntInt < ntInt
    ntBool = ntInt > ntInt
end

unary_properties = 50
binary_properties = 50

# signer, (unary_grammar, binary_grammar) = generate_property_signature(
#     grammar = grammar,
#     grammar_extension = grammar_extension,
#     input_symbol = :ntString,
#     output_symbol = :ntBool,
#     amount_of_unary_properties = unary_properties,
#     amount_of_binary_properties = binary_properties,
#     interpreter = interpret_sygus,
# )

# @show length(signer)

# states = first_n_states(
#     grammar = grammar,
#     start_symbol = :ntString,
#     amount_of_states = 500,
#     max_enumerations = 5000,
#     interpreter = p -> interpret_sygus(p, grammar, problem)
# )

# @show length(states)

# signs = create_property_signatures(signer, states, target)

# @show length(signer)

# println("\n\nUnary properties")

# for (program, property) in signer.unary_properties
#     expr = rulenode2expr(program, unary_grammar)
#     @show expr
# end

# println("\n\nBinary properties")

# for (program, property) in signer.binary_properties
#     expr = rulenode2expr(program, binary_grammar)
#     @show program
#     @show expr
# end


# target = ["Hello World"]

# states, programs = first_n_states(
#     grammar = grammar,
#     start_symbol = :ntString,
#     amount_of_states = 500,
#     max_enumerations = 5000,
#     interpreter = p -> interpret_sygus(p, grammar, ["Hello", "World"])
# )

@show binary_grammar

b1 = RuleNode(25, [RuleNode(34), RuleNode(33)])
b2 = RuleNode(23, [RuleNode(34), RuleNode(33)])
b3 = RuleNode(24, [RuleNode(34), RuleNode(33)])
b4 = RuleNode(22, [RuleNode(16, [RuleNode(34)]), RuleNode(16, [RuleNode(33)])])
b5 = RuleNode(30, [RuleNode(16, [RuleNode(34)]), RuleNode(16, [RuleNode(33)])])

bs = [b1, b2, b3, b4, b5]
es = [1, 0, 1, 0, 1]

# B1: contains_cvc(_arg_2, _arg_1)      1
# B2: prefixof_cvc(_arg_2, _arg_1)      1
# B3: suffixof_cvc(_arg_2, _arg_1)      0
# B4: length(_arg_1) == length(_arg_2)  0
# B5: length(_arg_1) != length(_arg_2)  1


function alter(counts, program, inc)
    r = get_rule(program)
    counts[r] += inc

    for c in program.children
        alter(counts, c, inc)
    end
end

rule_count = fill(0.0, 26)

for (input, program) in zip(states, programs)
    values = [interpret_sygus(b, binary_grammar, [input, "Hello World"]) for b in bs]
    # sim = sum([e == v for (e, v) in zip(es, values)])
    # sim = dot(es, values) / (norm(es) * norm(values))
    sim = sum([(e - v)^2 for (e, v) in zip(es, values)])
    alter(rule_count, program, sim)
end

s = sum(rule_count)
for (r, c) in zip(1:26, rule_count)
    v = c / s
    println("$v")
end

@show grammar