using HerbCore, HerbGrammar, HerbConstraints, HerbBenchmarks, HerbSearch, HerbSpecification
include("property_generation.jl")
include("bitvector_functions.jl")

benchmark = HerbBenchmarks.PBE_BV_Track_2018

# Idk 1
problem = benchmark.problem_PRE_100_10
grammar = benchmark.grammar_PRE_100_10
output_type = :Start

# Idk 2
problem = benchmark.problem_PRE_104_10
grammar = benchmark.grammar_PRE_104_10
output_type = :Start



target_outputs = [e.out for e in problem.spec]
inputs = [e.in for e in problem.spec]

grammar_extension = @cfgrammar begin
    Bool = Start == Start
    Bool = Start != Start
    Bool = Start < Start
    Bool = Start > Start
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
    boolean_type = :Bool,
    n_properties = 8000,
    n_programs = 4000,
)

# for p in properties
#     e = rulenode2expr(p, property_grammar)
#     @show e
# end