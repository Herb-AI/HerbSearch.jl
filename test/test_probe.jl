# Testing on their code
my_replace(x,y,z) = replace(x,y => z, count = 1)
my_concat(x::String,y::String) = x * y

grammar = @pcsgrammar begin 
    0.188 : S = arg
    0.188 : S =  "" 
    0.188 : S =  "<" 
    0.188 : S =  ">"
    0.188 : S = my_replace(S,S,S)
    0.059 : S = my_concat(S, S)
end
@testset "Simulate using the grammar from paper" begin

    @testset "Grammar works without errors" begin
        # run grammar multiple times on some inputs. It should not crash..
        for _ in 1:10
            program = rand(RuleNode, grammar, :S, 2)
            execute_on_input(grammar, program, Dict(:arg => "hello"))
        end
    end
    function get_bank_and_runtime(examples, level_limit)
        # crate the probe iterator
        iterator = ProbeSearchIterator(grammar, :S, examples, mean_squared_error, level_limit = level_limit)
        # run iterator
        timer = @timed program, state = Base.iterate(iterator)
        bank = state.bank
        # inspect the bank's length for each size
        bank_lengths = [length(list_of_programs) for list_of_programs ∈ bank]
        @show bank_lengths
        return bank_lengths, program, timer.time
    end

    @testset "Probe finds solution using enumeration in terms of probability" begin

        examples_1_2_3 = [
            IOExample(Dict(:arg => "a < 4 and a > 0"), "a  4 and a  0")    # <- e0 with correct space
            # IOExample(Dict(:arg => "a < 4 and a > 0"), "a 4 and a 0")    # <- e0 with incorrect space
            IOExample(Dict(:arg => "<open and <close>"), "open and close") # <- e1
            IOExample(Dict(:arg => "<Change> <string> to <a> number"), "Change string to a number")
        ]

        
        bank, program, runtime = get_bank_and_runtime(examples_1_2_3, 38)
        @testset "Correct lengths" begin
            # Figure 9 from research paper (Bank index is offset by one because of julia indexing)
            @test bank[3] == 4
            @test bank[9] == 15
            @test bank[21] == 1272
        end
        
        @testset "Correct output and runtime" begin

            @test !isnothing(program) # we found a solution
            @test runtime <= 5
        end
    end
    @testset "Probe works when using sized based enumeration" begin 
        examples_1_2 = [
            # IOExample(Dict(:arg => "a < 4 and a > 0"), "a  4 and a  0")    # <- e0 with correct space
            IOExample(Dict(:arg => "a < 4 and a > 0"), "a 4 and a 0")    # <- e0 with incorrect space
            IOExample(Dict(:arg => "<open and <close>"), "open and close") # <- e1
        ]

        bank_lengths, program, runtime, = get_bank_and_runtime(examples_1_2, 10)

        @testset "Correct lengths" begin
            # sized based assertions taken from the Probe Research paper Figure 7.
            println(bank_lengths)
            @test bank_lengths[1:5] == [0,4,0,9,6]
            @test bank_lengths[9:11] == [349,714,2048]
        end

        #= Test the following claim for the research paper when using sized based enumeration
            "This
            modest change to the search algorithm yields surprising efficiency improvements: our size-based
            bottom-up synthesizer is able to solve the remove-angles-short benchmark in only one second"
        =#
        @testset "Correct output and runtime" begin 
            # @test runtime <= 1
            # @test !isnothing(program) # we found a solution
        end
    end

    # for (i,list_of_programs) ∈ enumerate(bank)
    #     nr_programs = length(list_of_programs)
    #     println("level $(i - 1) : $(nr_programs)")
    #     if nr_programs > 0
    #         expressions = map(rulenode -> rulenode2expr(rulenode, grammar), list_of_programs)
    #         # for expr in expressions
    #         #     println(expr)
    #         # end
    #     end
    # end
end