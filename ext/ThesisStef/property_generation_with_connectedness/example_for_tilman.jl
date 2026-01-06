using HerbCore, HerbGrammar, HerbConstraints, HerbBenchmarks, HerbSearch, HerbSpecification

include("../property_generation/string_functions.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019

# ("+106 769-858-438") -> "106.769.858.438"
problem = benchmark.problem_phone_9_short
grammar = benchmark.grammar_phone_9_short

inputs = [e.in for e in problem.spec]

grammar_tags = get_relevant_tags(grammar)
    
program_iterator = SizeBasedBottomUpIterator(grammar, :ntString, max_size = 3)

@show grammar

for program in program_iterator
    expr = rulenode2expr(program, grammar)
    @show expr
    # for input in inputs
    #     output = interpret_sygus(program, grammar_tags, input)
    # end
end