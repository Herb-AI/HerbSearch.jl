my_replace(x,y,z) = replace(x,y => z, count = 1)

grammar = @pcsgrammar begin
    0.188 : S = arg
    0.188 : S =  "" 
    0.188 : S =  "<" 
    0.188 : S =  ">"
    0.188 : S = my_replace(S,S,S)
    0.059 : S = S * S
end
@testset "Simulate using the grammar from paper" begin

    @testset "Grammar works without errors" begin
        # run grammar multiple times on some inputs. It should not crash..
        for _ in 1:10
            program = rand(RuleNode, grammar, :S, 2)
            execute_on_input(grammar, program, Dict(:arg => "hello"))
        end
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
                        ProgramCache(prog1,[1,2,3,4],100),
                        ProgramCache(prog2,[1,2,3,4],2), # <- smallest cost solving most examples
                        ProgramCache(prog3,[1,2,3],1),
                    ],
                    [prog2]
                ),
                (
                    HerbSearch.selectpsol_first_cheapest,
                    [
                        ProgramCache(prog1,[1,2,3,4],100),
                        ProgramCache(prog2,[1,2,3,4],2), # <- smallest cost solving 4 examples
                        ProgramCache(prog3,[1,2,3],1),   # <- smallest cost solving 3 examples
                    ],
                    [prog2, prog3]
                ),
                (
                    HerbSearch.selectpsol_first_cheapest,
                    [
                        ProgramCache(prog1,[1,2,3,4],100), # <- smallest cost solving 4 examples
                        ProgramCache(prog2,[1,2],2),       # <- smallest cost solving 2 examples
                        ProgramCache(prog3,[1,2,3],1),     # <- smallest cost solving 3 examples
                    ],
                    [prog1, prog2, prog3]
                ),
                (
                    HerbSearch.selectpsol_largest_subset,
                    [
                        ProgramCache(prog1,[1,2,3,4],100), # <- smallest cost solving 4 examples (but first)
                        ProgramCache(prog2,[1,2,3,4],100), # <- smallest cost solving 4 examples (but not considered)
                        ProgramCache(prog3,[1,2],2),       
                    ],
                    [prog1]
                ),
                (
                    HerbSearch.selectpsol_first_cheapest,
                    [
                        ProgramCache(prog1,[1,2,3,4],100), # <- smallest cost solving 4 examples (but first)
                        ProgramCache(prog2,[1,2,3,4],100), # <- smallest cost solving 4 examples (but not considered) 
                        ProgramCache(prog3,[1,2],2),       # <- smallest cost solving 2 examples
                    ],
                    [prog1, prog3]
                ),
                (
                    HerbSearch.selectpsol_all_cheapest,
                    [
                        ProgramCache(prog1,[1,2,3,4],100), # <- smallest cost solving 4 examples
                        ProgramCache(prog2,[1,2,3,4],100), # <- smallest cost solving 4 examples
                        ProgramCache(prog3,[1,2],2),       # <- smallest cost solving 2 examples
                    ],
                    [prog1, prog2, prog3]
                ),
                (
                    HerbSearch.selectpsol_largest_subset,
                    [
                        ProgramCache(prog1,[1,2,3,4,5],100), # <- solves most programs
                        ProgramCache(prog2,[1,2,3,4],2), 
                        ProgramCache(prog3,[1,2,3],1),
                    ],
                    [prog1]
                ),
                (
                    HerbSearch.selectpsol_largest_subset,
                    [
                        ProgramCache(prog3,[1],1), # only one program
                    ],
                    [prog3]
                ),
                (
                    HerbSearch.selectpsol_first_cheapest,
                    [
                        ProgramCache(prog3,[1],1), # only one program
                    ],
                    [prog3]
                ),
                (
                    HerbSearch.selectpsol_largest_subset,
                    [
                        ProgramCache(prog1,[],1), # no solved examples
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
            function test_select_function(func_to_call,partial_sols, expected)
                partial_sols_filtered = func_to_call(partial_sols)
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
            iter = HerbSearch.GuidedSearchIteratorOptimzed(grammar, :S, examples, symboltable)

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
            iter = HerbSearch.GuidedSearchIteratorOptimzed(grammar, :S, examples, symboltable)

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
    end

    @testset "Running probe" begin
        examples = [
            IOExample(Dict(:arg => "a < 4 and a > 0"), "a  4 and a  0")    # <- e0 with correct space
            IOExample(Dict(:arg => "<open and <close>"), "open and close") # <- e1
        ]
        input = [example.in for example in examples]
        output = [example.out for example in examples]

        symboltable = SymbolTable(grammar)
        @testset "Running using sized based enumeration" begin
            HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_size(rule_index, grammar)
            iter = HerbSearch.GuidedSearchIterator(grammar, :S, examples, symboltable)
            runtime = @timed program = probe(examples, iter, identity, identity, 1, 10000)

            expression = rulenode2expr(program, grammar)
            @test runtime.time <= 1 

            received = execute_on_input(symboltable, expression, input)
            @test output == received
        end

        @testset "Running using probability based enumeration" begin
            # test currently fails..
            examples = [ 
                IOExample(Dict(:arg => "a < 4 and a > 0"), "a  4 and a  0")    
                IOExample(Dict(:arg => "<open and <close>"), "open and close")
                IOExample(Dict(:arg => "<Change> <string> to <a> number"), "Change string to a number")
            ]
            input = [example.in for example in examples]
            output = [example.out for example in examples]

            HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_prob(rule_index, grammar)
            @testset "Check rule cost computation" begin
                for i in 1:5
                    @test HerbSearch.calculate_rule_cost(i, grammar) == 2
                end
                # the rule with S * S should have cost 4
                @test HerbSearch.calculate_rule_cost(6, grammar) == 4
            end
            iter = HerbSearch.GuidedSearchIterator(grammar, :S, examples, symboltable)
            runtime = @timed program = probe(examples, iter, identity, identity, 5, 10000)

            expression = rulenode2expr(program, grammar)
            @test runtime.time <= 5 

            received = execute_on_input(symboltable, expression, input)
            @test output == received
        end
    end
    # TODO: Refactor tests using probe function call
    # function get_bank_and_runtime(examples, level_limit)
    #     # crate the probe iterator
    #     iterator = ProbeSearchIterator(grammar, :S, examples, mean_squared_error, level_limit = level_limit)
    #     # run iterator
    #     timer = @timed program, state = Base.iterate(iterator)
    #     bank = state.bank
    #     # inspect the bank's length for each size
    #     bank_lengths = [length(list_of_programs) for list_of_programs ∈ bank]
    #     @show bank_lengths
    #     return bank_lengths, program, timer.time
    # end

    # @testset "Probe finds solution using enumeration in terms of probability" begin

    #     examples_1_2_3 = [
    #         IOExample(Dict(:arg => "a < 4 and a > 0"), "a  4 and a  0")    # <- e0 with correct space
    #         # IOExample(Dict(:arg => "a < 4 and a > 0"), "a 4 and a 0")    # <- e0 with incorrect space
    #         IOExample(Dict(:arg => "<open and <close>"), "open and close") # <- e1
    #         IOExample(Dict(:arg => "<Change> <string> to <a> number"), "Change string to a number")
    #     ]


    #     bank, program, runtime = get_bank_and_runtime(examples_1_2_3, 38)
    #     @testset "Correct lengths" begin
    #         # Figure 9 from research paper (Bank index is offset by one because of julia indexing)
    #         @test bank[3] == 4
    #         @test bank[9] == 15
    #         @test bank[21] == 1272
    #     end

    #     @testset "Correct output and runtime" begin

    #         @test !isnothing(program) # we found a solution
    #         @test runtime <= 5
    #     end
    # end
    # @testset "Probe works when using sized based enumeration" begin 
    #     examples_1_2 = [
    #         # IOExample(Dict(:arg => "a < 4 and a > 0"), "a  4 and a  0")    # <- e0 with correct space
    #         IOExample(Dict(:arg => "a < 4 and a > 0"), "a 4 and a 0")    # <- e0 with incorrect space
    #         IOExample(Dict(:arg => "<open and <close>"), "open and close") # <- e1
    #     ]

    #     bank_lengths, program, runtime, = get_bank_and_runtime(examples_1_2, 10)

    #     @testset "Correct lengths" begin
    #         # sized based assertions taken from the Probe Research paper Figure 7.
    #         println(bank_lengths)
    #         @test bank_lengths[1:5] == [0,4,0,9,6]
    #         @test bank_lengths[9:11] == [349,714,2048]
    #     end

    #     #= Test the following claim for the research paper when using sized based enumeration
    #         "This
    #         modest change to the search algorithm yields surprising efficiency improvements: our size-based
    #         bottom-up synthesizer is able to solve the remove-angles-short benchmark in only one second"
    #     =#
    #     @testset "Correct output and runtime" begin 
    #         # @test runtime <= 1
    #         # @test !isnothing(program) # we found a solution
    #     end
    # end

end