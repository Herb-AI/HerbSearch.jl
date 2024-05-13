using HerbSearch
using Test

include("bad_iterator.jl")

function create_examples(f, range=20)
    return [IOExample(Dict(:x => x), f(x)) for x ∈ 1:range]
end

function seededMH(problemExamples)
    Random.seed!(123)
    return get_mh_enumerator(problemExamples, HerbSearch.mean_squared_error)
end

function test_vlns_runtime()
    @testset "Runtime of vlns stopping"  begin
        # test shows that enumeration 1,2 gives correct running time.
        # enumeration depth 3 and more gives a big difference
        for max_runtime ∈ [1, 2, 2.5, 2.7, 20] 
            for enumeration_depth ∈ [1,2,3]

                # impossible problem
                problemExamples = create_examples(x -> (x - 4) * (x - 8) * (x - 12))

                runtime_stats = @timed HerbSearch.generic_run((HerbSearch.Sequence, 
                [
                    (get_vlsn_enumerator(problemExamples, HerbSearch.mean_squared_error, enumeration_depth), ((time, iteration, cost)-> time > max_runtime), 10, problemExamples, grammar),
                ], 10, grammar)...;)
                
                @testset "Running vlns for $max_runtime seconds with $enumeration_depth enumdepth should stop at the right time" begin
                    _,_,cost = runtime_stats.value
                    # there is no way vlns solved this problem
                    @test cost != 0

                    println("Time",runtime_stats.time)
                    if runtime_stats.time > max_runtime + 0.2
                        error("Expected runtime was $max_runtime but in fact it was $(runtime_stats.time) ")
                    end
                end
            end
        end
    end
end

# test in the same repl by ```include("test/runtests.jl")`
grammar = HerbSearch.arithmetic_grammar

function create_algorithm_for_testing(algorithm, problemExamples; max_time)
    max_depth = 2 # constant for testing purposes
    return (algorithm, ((time, iteration, cost) -> time > max_time), max_depth, problemExamples, grammar)
end

function create_bad_alg(examples; max_time)
    return create_algorithm_for_testing(get_bad_iterator(), examples, max_time = max_time)
end

function create_mh(examples; max_time)
    return create_algorithm_for_testing(seededMH(examples), examples, max_time = max_time)
end

@testset "Combinators tests" verbose=true begin
    
    grammar = HerbSearch.arithmetic_grammar


    # @testset "Parallel tests" verbose=true begin
    #     simpleProblemExamples = create_examples(x -> x)
    #     @testset "Threads matter" begin
    #         # test fails if ran with no threads `julia  --project=. `
    #         # test passed if ran with more threads.
    #         # => Threads DO matter
    #         @test Threads.nthreads() >= 4
    #         runtime_stats = @timed HerbSearch.generic_run((HerbSearch.Parallel, 
    #         [
    #             create_bad_alg(simpleProblemExamples, max_time = 10),
    #             create_bad_alg(simpleProblemExamples, max_time = 10),
    #             create_mh(simpleProblemExamples, max_time = 2),
    #             create_bad_alg(simpleProblemExamples, max_time = 10),

    #         ], 10, grammar)...;)

            
    #         # even though a lot of bad iterators are nested MH will find the answer and succeed :)
    #         _,_,cost = runtime_stats.value
    #         @test cost == 0
    #         @test runtime_stats.time <= 5
    #     end

    #     @testset "Simple MH in parallel" begin
    #         runtime_stats = @timed HerbSearch.generic_run((HerbSearch.Parallel, 
    #         [
    #             create_mh(simpleProblemExamples, max_time = 1)

    #         ], 10, grammar)...;)

    #         _,_,cost = runtime_stats.value
    #         @test cost == 0
    #         @test runtime_stats.time <= 2
    #     end

    #     @testset "Parallel has runtime roughly equal to the longest running algorithm" begin
    #         runtime_stats = @timed HerbSearch.generic_run((HerbSearch.Parallel, 
    #         [
    #             create_bad_alg(simpleProblemExamples, max_time = 1),
    #             create_bad_alg(simpleProblemExamples, max_time = 1),
    #             create_bad_alg(simpleProblemExamples, max_time = 1),
    #             create_bad_alg(simpleProblemExamples, max_time = 2),
    #             create_bad_alg(simpleProblemExamples, max_time = 3),
    #         ], 10, grammar)...;)

    #         @test runtime_stats.time <= 3 + 0.2
    #     end
    # end

    @testset "Sequence test" verbose=true begin 
        problemExamples = create_examples(x -> x + 1)
        import HerbSearch: generic_run
        import HerbSearch: SequenceCombinator, ParallelThreadsCombinator

        @testset "MH in Sequence is fast" begin
            runtime_stats = @timed generic_run((SequenceCombinator, 
            [
                create_mh(problemExamples, max_time = 1)
            ], 10, grammar)...;)

            # time taken by one MH should be less than one second
            @test runtime_stats.time <= 1
        end

        @testset "Runtime is sum of Bad iterators" begin
            runtime_stats = @timed generic_run((SequenceCombinator, 
            [
                create_bad_alg(problemExamples, max_time=0.5),
                create_bad_alg(problemExamples, max_time=1.5)
            ], 10, grammar)...;)

            # sum of the time taken for all iterators. 0.2 is margin for compilation time and other errors in calculating time
            @test abs(0.5 + 1.5 - runtime_stats.time) <= 0.2
        end

        @testset "once MH finds the answer the search stops" begin
            runtime_stats = @timed generic_run((SequenceCombinator, 
            [
                create_bad_alg(problemExamples, max_time=0.5),
                create_bad_alg(problemExamples, max_time=1.5),
                create_mh(problemExamples, max_time = 1),

                # will never run
                create_bad_alg(problemExamples, max_time=1000),
            ], 10, grammar)...;)

            # sum of the time taken for first bad itearors plus fast MH
            @test 0.5 + 1.5 <= runtime_stats.time <= 0.5 + 1.5 + 1
        end

        # @testset "Sequence of has the right stopping time" begin 
        #     problem = create_examples(x -> x)
        #     specs = @timed generic_run((HerbSearch.Sequence, 
        #     [   
        #         create_bad_alg(problem, max_time = HerbSearch.MAX_SEQUENCE_RUNNING_TIME - 1),
        #         (HerbSearch.Sequence,[
        #             create_bad_alg(problem, max_time = HerbSearch.MAX_SEQUENCE_RUNNING_TIME - 1),
        #             (HerbSearch.Sequence,[
        #                 create_bad_alg(problem, max_time = HerbSearch.MAX_SEQUENCE_RUNNING_TIME - 1),
        #                 ],10,grammar
        #             ),
        #         ],10,grammar),

        #     ], 10, grammar)...;)
            
        #     _,_,cost = specs.value 
            
        #     @test (specs.time <= HerbSearch.MAX_SEQUENCE_RUNNING_TIME + 0.2)

            
        #     specs = @timed generic_run((HerbSearch.Sequence, 
        #     [   
        #         (HerbSearch.Sequence,[
        #             (HerbSearch.Sequence,[
        #                 (HerbSearch.Sequence,[
        #                     create_bad_alg(problem, max_time = HerbSearch.MAX_SEQUENCE_RUNNING_TIME - 1),
        #                     ],10,grammar
        #                 ),
        #             ],10,grammar
        #             ),
        #         ],10,grammar),
        #     ], 10, grammar)...;)
            
        #     @test (specs.time <= HerbSearch.MAX_SEQUENCE_RUNNING_TIME + 0.2)

        # end

        @testset "Generic run stops on max time even though stopping condition gives more time" begin
            # the maximum time is 3 seconds but it takes 2 seconds because of the maximum running time
            specs = @timed generic_run(
                get_bad_iterator(grammar), 
                ((time, iteration, cost) -> time > 3), 
                1, 
                problemExamples, 
                grammar,
                max_running_time = 2

            )
            println(specs.time)
            @test (2.0 <= specs.time <= 2.1)


            # it stops after the stopping condition (3 seconds)
            specs = @timed generic_run(
                get_bad_iterator(grammar), 
                ((time, iteration, cost) -> time > 3), 
                1, 
                problemExamples, 
                grammar,
                max_running_time = 20

            )
            println(specs.time)
            @test (3.0 <= specs.time <= 3.1)

        end
    end


end

# @testset "Meta Search runtime" begin 
#     problem = create_examples(x -> (x - 23239) * (x + 28347) * (x + x * 12817))

#     @testset "test_runtime_of_a_single_run_does_exceed_expected_runtime" begin
#         index = 4 # <- hardest problem
#         problem = Problem(problem)

#         for i ∈ 1:10
#             random_meta_program = rand(RuleNode, meta_grammar, :S)
#             expression = rulenode2expr(random_meta_program,meta_grammar)
#             specs = @timed output = evaluate_meta_program_on_problem(random_meta_program,problem)
            
#             maximum_time = HerbSearch.MAX_SEQUENCE_RUNNING_TIME + HerbSearch.LONGEST_RUNNING_ALG_TIME
#             if specs.time > maximum_time + 0.2 
#                 println("Failing program: $expression")
#             end
#             @test (specs.time <= maximum_time + 0.2) 
#         end
#     end
   
# end



