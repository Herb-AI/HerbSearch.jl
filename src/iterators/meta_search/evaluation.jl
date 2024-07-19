using JSON
using HerbSearch: generic_run
using Logging 
MAX_TIME_TO_RUN_ALG = 20 # in seconds 
AVERAGE_RUNS = 50        # nr repeated iterations of each algorithm
include("meta_alg_options.jl")

vannila_mh = (input_problem::Problem, input_grammar::AbstractGrammar)->begin 
    generic_run(
        VanillaIterator(
            MHSearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, max_depth = 10), 
            ((time, iteration, cost)->time > MAX_TIME_TO_RUN_ALG), 
            input_problem
        )
    )
end

vannila_vlns = (input_problem::Problem, input_grammar::AbstractGrammar)->begin 
    generic_run(
        VanillaIterator(
            VLSNSearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, neighbourhood_size = 2), 
            ((time, iteration, cost)-> time > MAX_TIME_TO_RUN_ALG),
            input_problem
        )
    )
end

vannila_sa = (input_problem::Problem, input_grammar::AbstractGrammar)->begin 
    generic_run(
        VanillaIterator(
            SASearchIterator(input_grammar, :X, input_problem.spec, mean_squared_error, initial_temperature = 5, temperature_decreasing_factor = 0.99, max_depth = 10), 
            ((time, iteration, cost)-> time > MAX_TIME_TO_RUN_ALG),
            input_problem
        )
    )
end
vannila_bfs = (input_problem::Problem, input_grammar::AbstractGrammar)->begin 
    generic_run(
        VanillaIterator(
            BFSIterator(input_grammar, :X, max_depth = 4), 
            ((time, iteration, cost)-> time > MAX_TIME_TO_RUN_ALG),
            input_problem
        )
    )
end
vannila_dfs = (input_problem::Problem, input_grammar::AbstractGrammar)->begin 
    generic_run(
        VanillaIterator(
            DFSIterator(input_grammar, :X, max_depth = 4), 
            ((time, iteration, cost)-> time > MAX_TIME_TO_RUN_ALG),
            input_problem
        )
    )
end

algorithm_options = 
[
    (vannila_mh,"MH"),
    (vannila_vlns,"VLNS"),
    (vannila_sa,"SA"),
    (vannila_bfs,"BFS"),
    (vannila_dfs,"DFS"),
    (supercomputer_run_3averages,"Run supercomputer 3 averages"),
    (supercomputer_run_5averages_moredepth,"Run supercomputer 5 averages and more depth"),
    (two_sa,"Two sas in parallel"),
    (complex_algorithm,"Very complex algorithm"),
    (my_alg,"My algorithm"),
]


function test_algorithm_on_problem(runner, alg_name; problem::Problem, max_time_to_run::Int, average_runs::Int)
    problem_cost = []
    solve_count = 0
    lk = ReentrantLock()

    # run the problem multiple times
    Threads.@threads for _ ∈ 1:average_runs

        start_time = time()
        best_program, cost = runner(problem, HerbSearch.arithmetic_grammar)
        runtime = time() - start_time

        if runtime > max_time_to_run + 1
            @warn ("The algorithm $alg_name took $runtime seconds which is more than the threshold of $max_time_to_run seconds.")
        end

        lock(lk) do
            if cost == 0
                solve_count += 1
            end
            push!(problem_cost, cost)
        end
    end

    return Dict(
        "solve_count" => solve_count,
        "costs" => problem_cost
    )
end    


function evaluate_algorithm(runner, alg_name; max_time_to_run::Int, average_runs::Int)
    # RUNS on test problems
    run_data = []
    # for each problem 
    lk = ReentrantLock()
    Threads.@threads for (problem, problem_text) ∈ HerbSearch.problems_test     
        output = test_algorithm_on_problem(runner,alg_name, problem=problem, max_time_to_run=max_time_to_run, average_runs = average_runs)
        lock(lk) do 
            push!(run_data,Dict(problem_text => output))
        end
    end
    return run_data
end


function run_alg_comparison()
    Logging.disable_logging(Info)
    output_data = []
    lk = ReentrantLock()
    Threads.@threads for (algorithm, algorithm_name) in algorithm_options
        output = evaluate_algorithm(algorithm, algorithm_name; max_time_to_run=MAX_TIME_TO_RUN_ALG, average_runs=AVERAGE_RUNS)
        lock(lk) do 
            println("Finished running algorithm $algorithm_name with output: $output")
            push!(output_data, Dict(algorithm_name => output))
            open("output_data.json","w") do f
                JSON.print(f, output_data, 4)
            end
        end
    end
end

function create_plot(data_array::Vector{Dict{String, Any}})
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
