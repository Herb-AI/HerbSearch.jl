my_replace(x, y, z) = replace(x, y => z, count=1)

grammar = @pcsgrammar begin
    0.188:S = arg
    0.188:S = ""
    0.188:S = "<"
    0.188:S = ">"
    0.188:S = my_replace(S, S, S)
    0.059:S = S * S
end
@testset "Simulate using the grammar from paper" begin

    @testset "Grammar works without errors" begin
        # run grammar multiple times on some inputs. It should not crash..
        for _ in 1:10
            program = rand(RuleNode, grammar, :S, 2)
            execute_on_input(grammar, program, Dict(:arg => "hello"))
        end
    end
    @testset "Cost probabilities are computed correctly" begin
        rule_costs = [HerbSearch.calculate_rule_cost_prob(rule, grammar) for rule ∈ eachindex(grammar.rules)]
        @test rule_costs == [2, 2, 2, 2, 2, 4]
    end
    @testset "Selection schemes for partial solutions" begin
        using HerbSearch: ProgramCache
        prog1 = RuleNode(1)
        prog2 = RuleNode(2)
        prog3 = RuleNode(3)
        parametrized_test(
            [
                (
                    HerbSearch.selectpsol_largest_subset,
                    [
                        ProgramCache(prog1, [1, 2, 3, 4], 100),
                        ProgramCache(prog2, [1, 2, 3, 4], 2), # <- smallest cost solving most examples
                        ProgramCache(prog3, [1, 2, 3], 1),
                    ],
                    [prog2]
                ),
                (
                    HerbSearch.selectpsol_first_cheapest,
                    [
                        ProgramCache(prog1, [1, 2, 3, 4], 100),
                        ProgramCache(prog2, [1, 2, 3, 4], 2), # <- smallest cost solving 4 examples
                        ProgramCache(prog3, [1, 2, 3], 1),   # <- smallest cost solving 3 examples
                    ],
                    [prog2, prog3]
                ),
                (
                    HerbSearch.selectpsol_first_cheapest,
                    [
                        ProgramCache(prog1, [1, 2, 3, 4], 100), # <- smallest cost solving 4 examples
                        ProgramCache(prog2, [1, 2], 2),       # <- smallest cost solving 2 examples
                        ProgramCache(prog3, [1, 2, 3], 1),     # <- smallest cost solving 3 examples
                    ],
                    [prog1, prog2, prog3]
                ),
                (
                    HerbSearch.selectpsol_largest_subset,
                    [
                        ProgramCache(prog1, [1, 2, 3, 4], 100), # <- smallest cost solving 4 examples (but first)
                        ProgramCache(prog2, [1, 2, 3, 4], 100), # <- smallest cost solving 4 examples (but not considered)
                        ProgramCache(prog3, [1, 2], 2),
                    ],
                    [prog1]
                ),
                (
                    HerbSearch.selectpsol_first_cheapest,
                    [
                        ProgramCache(prog1, [1, 2, 3, 4], 100), # <- smallest cost solving 4 examples (but first)
                        ProgramCache(prog2, [1, 2, 3, 4], 100), # <- smallest cost solving 4 examples (but not considered) 
                        ProgramCache(prog3, [1, 2], 2),       # <- smallest cost solving 2 examples
                    ],
                    [prog1, prog3]
                ),
                (
                    HerbSearch.selectpsol_all_cheapest,
                    [
                        ProgramCache(prog1, [1, 2, 3, 4], 100), # <- smallest cost solving 4 examples
                        ProgramCache(prog2, [1, 2, 3, 4], 100), # <- smallest cost solving 4 examples
                        ProgramCache(prog3, [1, 2], 2),       # <- smallest cost solving 2 examples
                    ],
                    [prog1, prog2, prog3]
                ),
                (
                    HerbSearch.selectpsol_all_cheapest,
                    [
                        ProgramCache(prog1, [1, 2, 3], 100), # <- 2nd smallest cost solving 4 examples
                        ProgramCache(prog2, [1, 2, 3], 60),  # <- smallest cost solving 4 examples
                        ProgramCache(prog3, [1, 2], 2),      # <- smallest cost solving 2 examples
                    ],
                    [prog2, prog3]
                ),
                (
                    HerbSearch.selectpsol_largest_subset,
                    [
                        ProgramCache(prog1, [1, 2, 3, 4, 5], 100), # <- solves most programs
                        ProgramCache(prog2, [1, 2, 3, 4], 2),
                        ProgramCache(prog3, [1, 2, 3], 1),
                    ],
                    [prog1]
                ),
                (
                    HerbSearch.selectpsol_largest_subset,
                    [
                        ProgramCache(prog3, [1], 1), # only one program
                    ],
                    [prog3]
                ),
                (
                    HerbSearch.selectpsol_first_cheapest,
                    [
                        ProgramCache(prog3, [1], 1), # only one program
                    ],
                    [prog3]
                ),
                (
                    HerbSearch.selectpsol_largest_subset,
                    [
                        ProgramCache(prog1, [], 1), # no solved examples
                    ],
                    [prog1]
                ),
                # empty list 
                (
                    HerbSearch.selectpsol_largest_subset,
                    Vector{ProgramCache}(), # <- empty list of partial soliution
                    []
                ),
                # empty list 
                (
                    HerbSearch.selectpsol_first_cheapest,
                    Vector{ProgramCache}(), # <- empty list of partial soliution
                    []
                ),
                # empty list 
                (
                    HerbSearch.selectpsol_all_cheapest,
                    Vector{ProgramCache}(), # <- empty list of partial soliution
                    []
                )
            ],
            function test_select_function(func_to_call, partial_sols, expected)
                partial_sols_filtered = func_to_call(partial_sols, Set{ProgramCache}())
                mapped_to_programs = map(cache -> cache.program, partial_sols_filtered)
                @test sort(mapped_to_programs) == sort(expected)
            end
        )
    end

    @testset "Running GuidedSearchIterator" begin
        examples = [
            IOExample(Dict(:arg => "a < 4 and a > 0"), "a  4 and a  0")    # <- e0 with correct space
            IOExample(Dict(:arg => "<open and <close>"), "open and close") # <- e1
        ]

        symboltable = SymbolTable(grammar)

        @testset "Running using size-based enumeration" begin
            HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_size(rule_index, grammar)
            iter = HerbSearch.GuidedSearchIterator(grammar, :S, examples, symboltable)

            max_level = 10
            state = nothing
            next = iterate(iter)
            while next !== nothing
                _, state = next
                if (state.level > max_level)
                    break
                end
                next = iterate(iter, state)
            end
            sizes = [length(level) for level in state.bank]
            @test sizes == [0, 4, 0, 9, 6, 27, 54, 115, 349, 714, 2048, 1]
        end

        @testset "Running using prob-based enumeration" begin
            examples = [
                IOExample(Dict(:arg => "a < 4 and a > 0"), "a  4 and a  0")    # <- e0 with correct space
                IOExample(Dict(:arg => "<open and <close>"), "open and close") # <- e1
                IOExample(Dict(:arg => "<Change> <string> to <a> number"), "Change string to a number")
            ]

            HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_prob(rule_index, grammar)
            iter = HerbSearch.GuidedSearchIterator(grammar, :S, examples, symboltable)

            max_level = 20
            state = nothing
            next = iterate(iter)
            while next !== nothing
                _, state = next
                if (state.level > max_level)
                    break
                end
                next = iterate(iter, state)
            end
            sizes = [length(level) for level in state.bank]
            @test sizes == [0, 0, 4, 0, 0, 0, 0, 0, 15, 0, 0, 0, 0, 0, 122, 0, 0, 0, 0, 0, 1305, 0, 0, 0, 0, 0, 1]
        end

        @testset "Multiple nonterminals" begin
            grammar = @pcsgrammar begin
                1 : A = 1
                1 : A = A - B
                1 : B = 2
                1 : C = A + B
            end

            examples = [
                IOExample(Dict(), 5)
            ]

            HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_size(rule_index, grammar)
            iter = HerbSearch.GuidedSearchIterator(grammar, :A, examples, SymbolTable(grammar))

            progs = []
            state = nothing
            next = iterate(iter)
            while next !== nothing
                prog, state = next
                push!(progs, prog)
                if (state.level > 1)
                    break
                end
                next = iterate(iter, state)
            end

            @test progs == [RuleNode(1), RuleNode(2, [RuleNode(1), RuleNode(3)])]
        end
    end

    @testset "Running probe" begin
        examples = [
            IOExample(Dict(:arg => "a < 4 and a > 0"), "a  4 and a  0")    # <- e0 with correct space
            IOExample(Dict(:arg => "<open and <close>"), "open and close") # <- e1
        ]
        input = [example.in for example in examples]
        output = [example.out for example in examples]

        symboltable = SymbolTable(grammar)

        cost_functions = [HerbSearch.calculate_rule_cost_size, HerbSearch.calculate_rule_cost_prob]
        select_functions = [HerbSearch.selectpsol_all_cheapest, HerbSearch.selectpsol_first_cheapest, HerbSearch.selectpsol_largest_subset]
        uniform_grammar = @pcsgrammar begin
            1:S = arg
            1:S = ""
            1:S = "<"
            1:S = ">"
            1:S = my_replace(S, S, S)
            1:S = S * S
        end
        @testset "Demo running probe with guided search" begin 
            iter = HerbSearch.GuidedSearchIterator(deepcopy(uniform_grammar), :S, examples, symboltable)

            program = probe(examples, iter, 5, 100)
            expression = rulenode2expr(program, uniform_grammar)

            received = execute_on_input(symboltable, expression, input)
            @test output == received
        end

        @testset "Demo running probe with BFS" begin 
            @testset "Can't find solution" begin
                @testset "iterator finished" begin
                    iter = BFSIterator(uniform_grammar, :S, max_depth = 3)
                    program = probe(examples, iter, 5, 100)
                    @test isnothing(program)
                end
                @testset "probe runs out of iterations" begin
                    iter = BFSIterator(uniform_grammar, :S, max_depth = 100)
                    program = probe(examples, iter, 1, 100)
                    @test isnothing(program)
                end
            end
            @testset "Can find solution" begin
                examples_easy = [
                    IOExample(Dict(:arg => "a<4"), "a4")    # one replace operation
                ]
        
                iter = BFSIterator(uniform_grammar, :S, max_depth = 3)
                program = probe(examples_easy, iter, 5, 100)

                received = execute_on_input(symboltable, rulenode2expr(program, uniform_grammar), [e.in for e in examples_easy])
                @test ["a4"] == received
            end

        end
        @testset "Running probe with all combinations of select and cost functions" begin
            for cost_func ∈ cost_functions
                for select_func ∈ select_functions
                    for grammar_to_use ∈ [uniform_grammar, grammar]
                        # overwrite calculate cost
                        HerbSearch.calculate_rule_cost(rule_index::Int, g::ContextSensitiveGrammar) = cost_func(rule_index, g)
                        # overwrite select function
                        HerbSearch.select_partial_solution(partial_sols::Vector{ProgramCache}, all_selected_psols::Set{ProgramCache}) = select_func(partial_sols, all_selected_psols)

                        deep_copy_grammar = deepcopy(grammar_to_use)
                        iter = HerbSearch.GuidedSearchIterator(deep_copy_grammar, :S, examples, symboltable)
                        max_time = 5
                        runtime = @timed program = probe(examples, iter, max_time, 100)
                        expression = rulenode2expr(program, grammar_to_use)
                        @test runtime.time <= max_time

                        received = execute_on_input(symboltable, expression, input)
                        @test output == received
                    end
                end
            end
        end
    end
end