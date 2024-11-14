using HerbCore
using HerbGrammar
using HerbSearch

include("grammar_optimiser.jl")

# Define some dummy ASTs
dummy_ast1 = RuleNode(2, [RuleNode(1), RuleNode(1)])
dummy_ast2 = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])
dummy_asts = [dummy_ast1, dummy_ast2]

# Define a dummy grammar
dummy_grammar = @csgrammar begin
    Int = 1
    Int = Int + Int
    Int = Int * Int
end

# Call the grammar_optimiser function
optimised_grammar = grammar_optimiser(dummy_asts, dummy_grammar, 1, 0.5)

println("Optimised Grammar: ", optimised_grammar)