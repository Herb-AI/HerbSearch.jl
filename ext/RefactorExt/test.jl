using Markdown
using InteractiveUtils
include("RefactorExt.jl")
using .RefactorExt
include("../../src/HerbSearch.jl")
using HerbCore, HerbGrammar, .HerbSearch, HerbSpecification, HerbBenchmarks


# Define simple grammar
grammar = @csgrammar begin
    Int = 1
    Int = Int + Int
    Int = Int * Int
    Int = Int - Int
    Int = Int / Int
    Int = 1 + Num
    Int = 1 + Int
    Num = 3
    Num = 4
    Num = 5
    Int = Num
end

function test_for_debug_success()
    ast1 = RuleNode(2, [RuleNode(1), RuleNode(6, [RuleNode(7)])])
    ast2 = RuleNode(2, [RuleNode(1), RuleNode(6, [RuleNode(8)])])
    ast3 = RuleNode(2, [RuleNode(1), RuleNode(6, [RuleNode(9)])])
    # 1 + (1 + (Num 3))
    # 1 + (1 + (Num 4))
    # 1 + (1 + (Num 5))
    useful_asts = [ast1, ast2, ast3]
    optimised_grammar = RefactorExt.HerbSearch.refactor_grammar(useful_asts, grammar)
    println("Optimised Grammar: ")
    println(optimised_grammar)
end


function test_for_debug_fail()
    ast1 = RuleNode(2, [RuleNode(1), RuleNode(7, [RuleNode(11, [RuleNode(8)])])])
    ast2 = RuleNode(2, [RuleNode(1), RuleNode(7, [RuleNode(11, [RuleNode(9)])])])
    ast3 = RuleNode(2, [RuleNode(1), RuleNode(7, [RuleNode(11, [RuleNode(10)])])])
    # 1 + (1 + (Int (Num 3)))
    # 1 + (1 + (Int (Num 4)))
    # 1 + (1 + (Int (Num 5)))
    useful_asts = [ast1, ast2, ast3]
    optimised_grammar = RefactorExt.HerbSearch.refactor_grammar(useful_asts, grammar)
    println("Optimised Grammar: ")
    println(optimised_grammar)
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
    optimised_grammar = RefactorExt.HerbSearch.refactor_grammar(useful_asts, grammar, 1)
    println("Optimised Grammar: ")
    println(optimised_grammar)
end

function test_no_compression()
    # Define two simple programs that are deemed to be useful
    # Program 1: 1 + 1
    # Program 2: 1 * 1
    ast1 = RuleNode(2, [RuleNode(1), RuleNode(1)])
    ast2 = RuleNode(3, [RuleNode(1), RuleNode(1)])
    useful_asts = [ast1, ast2]
    optimised_grammar = RefactorExt.HerbSearch.refactor_grammar(useful_asts, grammar, 1)
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
    optimised_grammar = RefactorExt.HerbSearch.refactor_grammar(useful_asts, grammar, 1)
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
    optimised_grammar = RefactorExt.HerbSearch.refactor_grammar(useful_asts, grammar, 1)
    println("Optimised Grammar: ")
    println(optimised_grammar)
end

function test_string_problems()
    # Load grammar and problems
    problem_grammar_pairs = get_all_problem_grammar_pairs(String_transformations_2020)
    problem_grammar_pairs = first(problem_grammar_pairs, 20)
    grammar = problem_grammar_pairs[1].grammar

    println("Initial grammar:")
    println(grammar)

    # Solve problems
    programs = Vector{RuleNode}([])

    for (i, pg) in enumerate(problem_grammar_pairs)
        problem = pg.problem.spec
        iterator = HerbSearch.DFSIterator(grammar, :Sequence, max_depth=7)
        program = synth_string_program(problem, grammar, iterator)

        if !isnothing(program)
            id = pg.identifier
            # println("\nProblem $i (id = $id)")
            # println("Solution found: ", program)
            push!(programs, program)
        end
    end
    
    # Optimize grammar
    optimised_grammar = RefactorExt.HerbSearch.refactor_grammar(programs, grammar, 4)
    
    println("Optimized grammar:")
    println(optimised_grammar)
end

function synth_string_program(problems::Vector{IOExample{Any, HerbBenchmarks.String_transformations_2020.StringState}}, grammar::ContextSensitiveGrammar, iterator::HerbSearch.ProgramIterator)
    objective_states = [problem.out for problem in problems]
    for program ∈ iterator
        states = [problem.in[:_arg_1] for problem in problems]
        grammartags = HerbBenchmarks.String_transformations_2020.get_relevant_tags(grammar)
        
        solved = true
        for (objective_state, state) in zip(objective_states, states)
            try
                final_state = HerbBenchmarks.String_transformations_2020.interpret(program, grammartags, state)
                
                if objective_state != final_state
                    solved = false
                    break
                end
            catch BoundsError
                break
            end

            
        end

        if solved
            return program
        end
    end
end

test_for_debug_success()
test_for_debug_fail()
# test_no_compression()
# test_simple()
# test_many_refactorings()
# test_one_plus_blank()
# test_string_problems()