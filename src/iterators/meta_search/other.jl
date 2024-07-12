function simple_test()
    expr = :(function f(input_problem::Problem, input_grammar::G) where {G<:AbstractGrammar}
        generic_run(
            SequenceCombinatorIterator(
                [
                VannilaIterator(
                    GeneticSearchIterator(input_grammar, :X,
                        problem.spec,
                        population_size=3,
                        mutation_probability=0.2,
                        always_keep_best_program=false,
                        maximum_initial_population_depth=3),
                    ((time, iteration, cost) -> time > 3),
                    input_problem
                ),
                VannilaIterator(
                    GeneticSearchIterator(input_grammar, :X,
                        problem.spec,
                        population_size=1,
                        mutation_probability=0.2,
                        always_keep_best_program=false,
                        maximum_initial_population_depth=3),
                    ((time, iteration, cost) -> time > 4),
                    input_problem
                ),
                VannilaIterator( BFSIterator(input_grammar, :X, max_depth=5), 
                    ((time, iteration, cost) -> time > 4),
                    input_problem
                )
            ]
            )
        )
    end)

    problem, problem_text = problems_train[4]
    # Random.seed!(42)

    @show expr
    evaluate_meta_program(expr, problem, arithmetic_grammar)
end

function create_plot()
    mh_runner(examples, error_on_array) = get_mh_enumerator(examples, error_on_array)

    # TODO : Change before running on super computer
    VLNS_neighbourhood_size = 2
    vlns_runner(examples, error_on_array) = get_vlsn_enumerator(examples, error_on_array, VLNS_neighbourhood_size)

    max_time_to_run = 30
    mh_run = test_algorithm(mh_runner, max_time_to_run)
    println("MH: ", mh_run)

    vlns_run = test_algorithm(vlns_runner, max_time_to_run)
    println("vlns: ", vlns_run)

    # meta_arr = test_meta_algorithm()
    meta_arr = [4, 3, 3, 4, 3, 4, 3, 3, 3, 4, 4, 3, 3, 3, 4, 4, 3, 4, 3, 3]

    boxplot1 = box(y=mh_run, name="MH", boxpoints="all")
    boxplot2 = box(y=vlns_run, name="VLNS", boxpoints="all")
    boxplot3 = box(y=meta_arr, name="MetaSearch", boxpoints="all")

    plot([boxplot1, boxplot2, boxplot3],
        Layout(
            xaxis_title="Algorithm",
            yaxis_title="Solved problems out of 5",
            title="Nr of solved problems for each algorithm. 30 seconds for each algorithm",
            xanchor="center",
            yanchor="top",
            x=0.9,
            y=0.5)
    )
end

function test_runtime_of_a_single_fitness_evaluation()
    # max sequence is
    for i ∈ 1:10
        random_meta_program = rand(RuleNode, meta_grammar, :S)
        expression = rulenode2expr(random_meta_program, meta_grammar)
        specs = @timed output = HerbSearch.fitness_function(random_meta_program, 1)

        maximum_time_single_run = HerbSearch.MAX_SEQUENCE_RUNNING_TIME + HerbSearch.LONGEST_RUNNING_ALG_TIME
        total_max_time = length(problems_train) * 3 * maximum_time_single_run

        println("Total runtime $(specs.time) seconds. Maximum $total_max_time")
        @assert (specs.time <= total_max_time + 0.2) "$(specs.time) exceeded $total_max_time. \n$expression"
        println("===================")
    end
end

# input_grammar = HerbSearch.arithmetic_grammar
# problem, problem_text = problems_train[4]
# generic_run(
#             ParallelCombinatorIterator(ParallelNoThreads, 
#             [
#                 VanillaIterator(VLSNSearchIterator(input_grammar, :X, problem.spec, mean_squared_error, neighbourhood_size = 2), ((time, iteration, cost)-> time > 4 || iteration > 2000), problem),
#                 SequenceCombinatorIterator(
#                     [
#                         # VanillaIterator(
#                         #     GeneticSearchIterator(input_grammar, :X,
#                         #         problem.spec,
#                         #         population_size=1,
#                         #         mutation_probability=0.2,
#                         #         always_keep_best_program=false,
#                         #         maximum_initial_population_depth=3),
#                         #     ((time, iteration, cost) -> time > 4),
#                         #     problem
#                         # ),
#                         VanillaIterator(VLSNSearchIterator(input_grammar, :X, problem.spec, mean_squared_error, neighbourhood_size = 2), ((time, iteration, cost)-> time > 4 || iteration > 2000), problem),
#                     ]
#                 ),   
#                 ParallelCombinatorIterator(
#                     ParallelThreads,
#                     [
#                         VanillaIterator(BFSIterator(input_grammar, :X, max_depth = 4), ((time, iteration, cost)->time > 4 || iteration > 2000), problem),
#                         VanillaIterator(MHSearchIterator(input_grammar, :X, problem.spec, mean_squared_error, max_depth = 10), ((time, iteration, cost)->time > 5 || iteration > 5000), problem),
#                         VanillaIterator(SASearchIterator(input_grammar, :X, problem.spec, mean_squared_error, initial_temperature = 5, temperature_decreasing_factor = 0.93, max_depth = 10), ((time, iteration, cost)->time > 5 || iteration > 5000), problem)
#                     ]
#                 )
#         ]))


