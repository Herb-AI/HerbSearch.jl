using Markdown
using InteractiveUtils
include("RefactorExt.jl")
using .RefactorExt
using HerbCore, HerbGrammar, HerbSearch


# Define simple grammar
grammar = @csgrammar begin
    Int = 1
    Int = Int + Int
    Int = Int * Int
end


# Define two simple programs that are deemed to be useful
# Program 1: 1 + 1
# Program 2: (1 + 1) * (1 + 1)
ast1 = RuleNode(2, [RuleNode(1), RuleNode(1)])
ast2 = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])
useful_asts = [ast1, ast2]


# Optimize grammar by substituting 1 + 1 as a new grammar rule
optimised_grammar = RefactorExt.HerbSearch.refactor_grammar(useful_asts, grammar, RefactorExt.SelectionStrategy(0), 0.5)
println("Optimised Grammar: ", optimised_grammar)