using HerbSearch
using Test

include("bad_iterator.jl")

grammar = HerbSearch.arithmetic_grammar

function stopping_condition_with_max_time(max_time)
    return (time, iteration, cost) -> time > max_time
end 

function create_mh(problem::Problem; max_time)
    Random.seed!(42)
    return VanillaIterator(MHSearchIterator(grammar, :X, problem.spec, HerbSearch.mean_squared_error, max_depth=10), stopping_condition_with_max_time(max_time), problem)
end
function create_bad_alg(problem::Problem; max_time)
    return VanillaIterator(BadIterator(grammar, :X), stopping_condition_with_max_time(max_time), problem)
end

function test_time_interval(actual_runtime, desired_runtime, threshold = 0.2) 
    @test abs(actual_runtime - desired_runtime) <= threshold 
end

@testset "Sequence tests" begin 
    @testset "MH stops when maxtime is reached"  begin
        # impossible problem
        impossible_problem, examples = create_problem(x -> (x - 4) * (x - 8) * (x - 12))
        for max_runtime ∈ [ 2.5, 2.7] 
            @testset "Running sequence stops at the given $max_runtime time" begin
                runtime_stats = @timed HerbSearch.generic_run(
                    SequenceCombinatorIterator(
                        [
                            VanillaIterator(MHSearchIterator(grammar, :X, examples, HerbSearch.mean_squared_error, max_depth=10), stopping_condition_with_max_time(max_runtime), impossible_problem),
                        ],
                    ),
                    max_running_time = max_runtime
                )
                program, cost = runtime_stats.value
                @test cost != 0 # the problem is impossible to solve
                test_time_interval(runtime_stats.time, max_runtime)
            end
        end
    end
    
end

@testset "Parallel tests" verbose=true begin
    simpleProblem, examples = create_problem(x -> x * x)
    runtime_mh = 2
    runtime_bad_alg = 3
    algorithms = [
        create_bad_alg(simpleProblem, max_time = runtime_bad_alg),
        create_bad_alg(simpleProblem, max_time = runtime_bad_alg),
        create_mh(simpleProblem, max_time = runtime_mh),
        create_bad_alg(simpleProblem, max_time = runtime_bad_alg),
    ]
    
    @testset "Threads go faster in parallel because of early stop" begin
        # test fails if ran with no threads `julia  --project=. test passes if ran with more threads.
        # Threads DO matter for this test case.
        @test Threads.nthreads() >= 4
        runtime_stats = @timed HerbSearch.generic_run(ParallelCombinatorIterator(
            ParallelThreads,
            algorithms)
        )

        # even though a lot of bad iterators are nested MH will find the answer and succeed :)
        _,cost = runtime_stats.value
        @test cost == 0
        @test runtime_stats.time <= runtime_mh + 0.2
    end
    @testset "Parallel without threads is slower" begin
        runtime_stats = @timed HerbSearch.generic_run(
            ParallelCombinatorIterator(
                ParallelNoThreads,
                algorithms
            )
        )
        # no parallel will result in serial operations which will take longer
        _,cost = runtime_stats.value
        @test cost == 0
        # it has to run first two bad iterators and after that it runs mh
        @test 2 * runtime_bad_alg <= runtime_stats.time <= runtime_mh + 2 * runtime_bad_alg
    end
    
    dumb_algorithms = [
        create_bad_alg(simpleProblem, max_time = 1),
        create_bad_alg(simpleProblem, max_time = 1),
        create_bad_alg(simpleProblem, max_time = 2),
        create_bad_alg(simpleProblem, max_time = 3),
    ]
    @testset "Parallel has runtime roughly equal to the longest running algorithm" begin
        runtime_stats = @timed HerbSearch.generic_run(
            ParallelCombinatorIterator(
                ParallelThreads,
                dumb_algorithms,
            )
        )
        maximum_waiting_time = 3
        test_time_interval(runtime_stats.time, maximum_waiting_time)
    end
    @testset "Sequence and Parallel takes into account max_time=3" begin
        maximum_runtime = 3

        runtime_stats = @timed HerbSearch.generic_run(
            SequenceCombinatorIterator(
                dumb_algorithms,
            ),
            max_running_time = maximum_runtime
        )
        test_time_interval(runtime_stats.time, maximum_runtime)

        runtime_stats = @timed HerbSearch.generic_run(
            ParallelCombinatorIterator(
                ParallelThreads,
                dumb_algorithms,
            ),
            max_running_time = maximum_runtime
        )
        test_time_interval(runtime_stats.time, maximum_runtime)
    end
end


@testset "Meta Search" begin 
    problem, examples = create_problem(x -> (x - 23239) * (x + 28347) * (x + x * 12817))
    @testset "Sampling and running 10 meta programs works" begin

        for i ∈ 1:10
            random_meta_program = rand(RuleNode, meta_grammar, :S)
            expression = rulenode2expr(random_meta_program, meta_grammar)
            # println("Running expression $expression")

            runtime = @timed cost,program = evaluate_meta_program(expression, problem, HerbSearch.arithmetic_grammar)
            # the maximum runtime should be roughly equal to the max sequence running time.
            # Note: if a lot of threads are spawned that do not fit on physical cores, this runtime can exceed.
            @test runtime.time <= HerbSearch.MAX_SEQUENCE_RUNNING_TIME + 1
        end
    end
    @testset "Running complex algorithm sequence" begin 
        input_grammar = HerbSearch.arithmetic_grammar

        runtime = @timed HerbSearch.generic_run(
            ParallelCombinatorIterator(ParallelNoThreads, 
            [
                VanillaIterator(VLSNSearchIterator(input_grammar, :X, problem.spec, mean_squared_error, neighbourhood_size = 2), ((time, iteration, cost)-> time > 4 || iteration > 2000), problem),
                SequenceCombinatorIterator(
                    [
                        VanillaIterator(
                            GeneticSearchIterator(input_grammar, :X,
                                problem.spec,
                                population_size=1,
                                mutation_probability=0.2,
                                always_keep_best_program=false,
                                maximum_initial_population_depth=3),
                            ((time, iteration, cost) -> time > 4),
                            problem
                        ),
                        VanillaIterator(VLSNSearchIterator(input_grammar, :X, problem.spec, mean_squared_error, neighbourhood_size = 2), ((time, iteration, cost)-> time > 4 || iteration > 2000), problem),
                    ]
                ),   
                ParallelCombinatorIterator(
                    ParallelThreads,
                    [
                        VanillaIterator(BFSIterator(input_grammar, :X, max_depth = 4), ((time, iteration, cost)->time > 4 || iteration > 2000), problem),
                        VanillaIterator(MHSearchIterator(input_grammar, :X, problem.spec, mean_squared_error, max_depth = 10), ((time, iteration, cost)->time > 5 || iteration > 5000), problem),
                        VanillaIterator(SASearchIterator(input_grammar, :X, problem.spec, mean_squared_error, initial_temperature = 5, temperature_decreasing_factor = 0.93, max_depth = 10), ((time, iteration, cost)->time > 5 || iteration > 5000), problem)
                    ]
                )
        ]))
        @test runtime.time <= HerbSearch.MAX_SEQUENCE_RUNNING_TIME + 2
    end
    @testset "Running algorithms consecutively" begin 
        input_grammar = HerbSearch.arithmetic_grammar
        for (input_problem, text) in HerbSearch.problems_train
            output = HerbSearch.generic_run(SequenceCombinatorIterator(
                [
                    VanillaIterator(BFSIterator(input_grammar, :X, max_depth = 4), stopping_condition_with_max_time(1), input_problem),
                    VanillaIterator(BFSIterator(input_grammar, :X, max_depth = 4), stopping_condition_with_max_time(1), input_problem),
                    VanillaIterator(VLSNSearchIterator(input_grammar, :X, problem.spec, mean_squared_error, neighbourhood_size = 2), stopping_condition_with_max_time(1), input_problem),
                    VanillaIterator(VLSNSearchIterator(input_grammar, :X, problem.spec, mean_squared_error, neighbourhood_size = 2), stopping_condition_with_max_time(1), input_problem),
                    VanillaIterator(MHSearchIterator(input_grammar, :X, problem.spec, mean_squared_error), stopping_condition_with_max_time(1), input_problem),
                    VanillaIterator(MHSearchIterator(input_grammar, :X, problem.spec, mean_squared_error), stopping_condition_with_max_time(1), input_problem),
                ]
            ))
        end
    end
end
