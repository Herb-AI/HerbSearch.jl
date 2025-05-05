using Markdown
using InteractiveUtils
include("RefactorExt.jl")
using .RefactorExt
include("../../src/HerbSearch.jl")
using HerbCore, HerbGrammar, .HerbSearch


# Define simple grammar
grammar = @csgrammar begin
    Int = 1
    Int = Int + Int
    Int = Int * Int
    Int = Int - Int
    Int = Int / Int
end

function test_simple()
    # Define two simple programs that are deemed to be useful
    # Program 1: 1 + 1
    # Program 2: ((1 + 1) * (1 + 1)) + ((1 / 1) * (1 + 1))
    ast1 = RuleNode(2, [RuleNode(1), RuleNode(1)])
    ast2 = RuleNode(2, [
        RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])]),
        RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(5, [RuleNode(1), RuleNode(1)])])
    ])
    # Program 2: (1 + 1) * (1 + 1)
    #ast2 = RuleNode(3, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(1), RuleNode(1)])])
    useful_asts = [ast1, ast2]#[ast2, ast1]
    optimised_grammar = RefactorExt.HerbSearch.refactor_grammar(useful_asts, grammar)
    println("Optimised Grammar: ")
    println(optimised_grammar)
end

function test_many_refactorings()
    # Program 1: (1 + 1) + ((1 - 1) + (1 - 1))
    # Program 2: (1 + 1) + ((1 * 1) + (1 * 1))
    # Program 3: (1 + 1) + ((1 / 1) + (1 / 1))
    ast1 = RuleNode(2, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(3, [RuleNode(1), RuleNode(1)]),RuleNode(3, [RuleNode(1), RuleNode(1)])])])
    ast2 = RuleNode(2, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(4, [RuleNode(1), RuleNode(1)]),RuleNode(4, [RuleNode(1), RuleNode(1)])])])
    ast3 = RuleNode(2, [RuleNode(2, [RuleNode(1), RuleNode(1)]), RuleNode(2, [RuleNode(5, [RuleNode(1), RuleNode(1)]),RuleNode(5, [RuleNode(1), RuleNode(1)])])])
    useful_asts = [ast1, ast2, ast3]
    optimised_grammar = RefactorExt.HerbSearch.refactor_grammar(useful_asts, grammar)
    println("Optimised Grammar: ")
    println(optimised_grammar)
end

function test_one_plus_blank()
   # (1 + (1 + 1)) 2{1,3{1,1}}
    # (1 + (1 - 1))
    # 1 + 1
    ast1 = RuleNode(2, [RuleNode(1), RuleNode(2, [RuleNode(1), RuleNode(1)])])
    ast2 = RuleNode(2, [RuleNode(1), RuleNode(4, [RuleNode(1), RuleNode(1)])])
    ast3 = RuleNode(2, [RuleNode(1), RuleNode(1)])
    useful_asts = [ast1, ast2, ast3]

    # Optimize grammar by substituting 1 + 1 as a new grammar rule
    optimised_grammar = RefactorExt.HerbSearch.refactor_grammar(useful_asts, grammar)
    println("Optimised Grammar: ")
    println(optimised_grammar) 
end

test_simple()
test_many_refactorings()
test_one_plus_blank()

#subtrees = vcat(Vector{Any}(), RefactorExt.enumerate_subtrees(ast1, grammar))
#res = RefactorExt.convert_subtrees_to_json(subtrees, ast1)
#println(RefactorExt.parse_json(res))

#=

Subtrees of 1 + 1:
- _ + _
- 1 + _
- _ + 1
_ 1 + 1
_ 1

=#