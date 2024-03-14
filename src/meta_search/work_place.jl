using HerbInterpret
using HerbGrammar
using HerbSpecification
using HerbSearch
using Logging
# using Statistics
# using PlotlyJS

import Random


Logging.disable_logging(Logging.LogLevel(1))

function get_meta_algorithm()
    @time output = run_meta_search((current_time, i, fitness) -> i > 1000)
    println("Output of meta search is: ", output)
    return output
end

function create_plot()
    mh_runner(examples,error_on_array) = get_mh_enumerator(examples, error_on_array)

    # TODO : Change before running on super computer
    VLNS_ENUMERATION_DEPTH = 2
    vlns_runner(examples,error_on_array) = get_vlsn_enumerator(examples, error_on_array, VLNS_ENUMERATION_DEPTH)

    max_time_to_run = 30
    mh_run = test_algorithm(mh_runner,max_time_to_run)
    println("MH: ",mh_run)

    vlns_run = test_algorithm(vlns_runner,max_time_to_run)
    println("vlns: ",vlns_run)

    # meta_arr = test_meta_algorithm()
    meta_arr = [4, 3, 3, 4, 3, 4, 3, 3, 3, 4, 4, 3, 3, 3, 4, 4, 3, 4, 3, 3]

    boxplot1 = box(y = mh_run, name="MH", boxpoints="all");
    boxplot2 = box(y = vlns_run, name="VLNS", boxpoints="all");
    boxplot3 = box(y = meta_arr, name="MetaSearch", boxpoints="all");

    plot([boxplot1, boxplot2,boxplot3],
        Layout(
            xaxis_title="Algorithm",
            yaxis_title="Solved problems out of 5",
            title="Nr of solved problems for each algorithm. 30 seconds for each algorithm",
            xanchor="center",
            yanchor= "top",
            x=0.9,
            y=0.5)
    )
end

function test_runtime_of_a_single_fitness_evaluation()
    # max sequence is
    for i ∈ 1:10
        random_meta_program = rand(RuleNode, meta_grammar, :S)
        expression = rulenode2expr(random_meta_program,meta_grammar)
        specs = @timed output = HerbSearch.fitness_function(random_meta_program,1)
        
        maximum_time_single_run = HerbSearch.MAX_SEQUENCE_RUNNING_TIME + HerbSearch.LONGEST_RUNNING_ALG_TIME
        total_max_time = length(problems_train) * 3 * maximum_time_single_run

        println("Total runtime $(specs.time) seconds. Maximum $total_max_time")
        @assert (specs.time <= total_max_time + 0.2) "$(specs.time) exceeded $total_max_time. \n$expression"
        println("===================")
    end
end

get_meta_algorithm()