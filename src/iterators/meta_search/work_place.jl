using HerbInterpret
using HerbGrammar
using HerbSpecification
using HerbSearch
using Logging
# using Statistics
# using PlotlyJS

import Random
include("meta_search.jl")

function print_meta_configuration()
    println("CONFIGURATION")
    println("- Number of available threads: ", Threads.nthreads())
    println("- Maximum sequence running time: $MAX_SEQUENCE_RUNNING_TIME")
    println("- Longest time maximum given to an algorithm: $LONGEST_RUNNING_ALG_TIME")

    dump(meta_configuration)
    println("=========================================")
    @show meta_grammar
    println("=========================================")
    println("Genetic algorithm always adds the best program so far in the population")

    # The estimates below do not take into account the threads
    function estimate_runtime_of_one_algorithm()
        return LONGEST_RUNNING_ALG_TIME
    end

    function estimate_runtime_of_fitness_function()
        return estimate_runtime_of_one_algorithm() * length(problems_train) * fitness_configuration.number_of_runs_to_average_over
    end

    function estimate_runtime_of_one_genetic_iteration()
        # hope that the each chromosome fitness computation runs in parallel
        # add a bit of extra time to do cross over and mutation
        return estimate_runtime_of_fitness_function() + 2
    end

    println("ESTIMATES")
    println("Estimate one run       : ", estimate_runtime_of_one_algorithm())
    println("Estimate one fitness   : ", estimate_runtime_of_fitness_function())
    println("Estimate one iteration : ", estimate_runtime_of_one_genetic_iteration())
    println("Estimates do not take into account the numeber of threads used")
end



function get_meta_algorithm()
    Logging.disable_logging(Logging.LogLevel(1))
    print_meta_configuration()

    @time output = run_meta_search((current_time, i, fitness) -> i > 100)
    println("Output of meta search is: ", output)
    return output
end

function create_plot()
    mh_runner(examples, error_on_array) = get_mh_enumerator(examples, error_on_array)

    # TODO : Change before running on super computer
    VLNS_ENUMERATION_DEPTH = 2
    vlns_runner(examples, error_on_array) = get_vlsn_enumerator(examples, error_on_array, VLNS_ENUMERATION_DEPTH)

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

get_meta_algorithm()