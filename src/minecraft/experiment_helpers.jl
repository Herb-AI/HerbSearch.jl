include("minerl.jl")
include("utils.jl")

using Base.Filesystem
using HerbGrammar, HerbSpecification, HerbInterpret, HerbSearch, HerbCore
using Logging
using Random
using JSON
using Dates

"""
    create_experiment_file(directory_path::String, experiment_name::String)

Creates a new experiment file in the given directory with the given name. If a file with the same name already exists, it will create a new file with an incremented index.
The experiment name should not contain the ".json" extension.
"""
function create_experiment_file(; directory_path::String, experiment_name::String)
    mkpath(directory_path)
    experiment_name = replace(experiment_name, ".json" => "")
    file_path = joinpath(directory_path, experiment_name * ".json")

    if isfile(file_path)
        printstyled("[$(Dates.Time(Dates.now()))] File $file_path already exists. Creating a new one with incremental index\n", color=:yellow)

        index = 1
        while isfile(file_path)
            index += 1
            file_name = "$experiment_name" * "_$index.json"
            file_path = joinpath(directory_path, file_name)
        end
        printstyled("[$(Dates.Time(Dates.now()))] Created experiment file at $file_path\n", color=:green)
    end
    open(file_path, "w") do f
        write(f, "")
    end
    return file_path
end


function append_to_json_file(filepath, new_data)
    open(filepath, "r") do file
        json_data = JSON.parse(read(file, String))
        json_data = [json_data; new_data]
        open(filepath, "w") do f
            write(f, json(json_data, 4))
        end
    end
end

Base.@kwdef struct ExperimentConfiguration
    directory_path::String           # path to the folder where the experiment will be stored 
    experiment_description::String   # name of the experiment
    number_of_runs::Int              # number of runs to run the experiment, for each world and FrAngel seed
    max_run_time::Int                # maximum runtime of one run of an experiment
    render_moves::Bool               #  boolean to render the moves while running
end

create_iterator_frangel(grammar::AbstractGrammar, symbol::Symbol, rules_min::Vector{UInt8}, symbol_min::Dict{Symbol,UInt8}, frangel_config::FrAngelConfig) = FrAngelRandomIterator(grammar, symbol, rules_min, symbol_min, max_depth=frangel_config.generation.max_size)

Base.@kwdef mutable struct RunInfo
    iterations::Int=0
    start_time::Float64=0.0
    prev_reward::Float64=0.0
end

# Initialize variables for logging
starting_times = Vector{Float64}()
fragments_history = Vector{Tuple{Float64, Vector{RuleNode}}}()
generated_programs = Vector{Tuple{Float64, RuleNode}}()
evaluated_programs = Vector{Tuple{Float64, Float64, RuleNode}}() 
used_fragments = Vector{Tuple{Float64, RuleNode}}()
run_info = RunInfo()

HerbSearch.on_intialization() = begin
    push!(starting_times, (time() - run_info.start_time))
    run_info.iterations = 0
end 
HerbSearch.on_fragments_mined(fragments::AbstractVector{RuleNode}) = push!(fragments_history, (time() - run_info.start_time, deepcopy(fragments)))
HerbSearch.on_fragment_used(fragment::RuleNode) = push!(used_fragments, (time() - run_info.start_time, deepcopy(fragment)))
HerbSearch.on_program_evaluated(program::RuleNode, passed_tests::BitVector, program_state) = push!(evaluated_programs, (time() - run_info.start_time, run_info.prev_reward + program_state.total_reward, deepcopy(program)))
HerbSearch.on_iteration() = run_info.iterations += 1
HerbSearch.on_new_program_generated(program::RuleNode) = push!(generated_programs, (time() - run_info.start_time, deepcopy(program)))

"""
    run_frangel_once(grammar_config::MinecraftGrammarConfiguration, frangel_config::FrAngelConfig, specification_config::SpecificationConfiguration, max_synthesis_runtime::Int)

The function that performs a single experiment run. Runs FrAngel on MineRL with the given configurations and returns the runtime, reward over time and if the task was solved.
"""
function run_frangel_once(;
    grammar_config::MinecraftGrammarConfiguration,
    frangel_config::FrAngelConfig,
    specification_config::SpecificationConfiguration,
    max_synthesis_runtime::Int,
    create_iterator::Function = create_iterator_frangel,
)
    # Init
    grammar, angelic_conditions = grammar_config.minecraft_grammar, grammar_config.angelic_conditions
    current_max_possible_reward = specification_config.max_reward

    # Prepare environment for experiment
    if environment.env.done
        reset_env(environment)
    else
        soft_reset_env(environment, environment.start_pos)
    end

    try_data = Dict{String, Any}("iterations" => [])

    start_time = time()
    has_solved_task = false
    starting_position = environment.start_pos
    start_reward = 0.0

    empty!(starting_times)
    empty!(fragments_history)
    empty!(generated_programs)
    empty!(evaluated_programs)
    empty!(used_fragments)
    run_info.start_time = start_time
    run_info.prev_reward = start_reward

    # Main loop - run for as long as the experiment allows
    while time() - start_time < max_synthesis_runtime
        iter_start_time = time()
        initial_position = deepcopy(starting_position)

        # Run
        rules_min = rules_minsize(grammar)
        symbol_min = symbols_minsize(grammar, rules_min)
        # Create new test spec and iterator
        iter_frangel_config = deepcopy(frangel_config)
        problem_specification = create_spec(current_max_possible_reward, specification_config.reward_percentages, specification_config.require_done, starting_position)
        iterator = create_iterator(deepcopy(grammar), :Program, rules_min, symbol_min, iter_frangel_config)
        # Generate next FrAngel program, and update environment state
        try
            solution = frangel(problem_specification, iter_frangel_config, angelic_conditions, iterator, rules_min, symbol_min)
            # If the solution passes at least one test
            if !isnothing(solution)
                state = execute_on_input(grammar, solution, Dict{Symbol,Any}(:start_pos => starting_position))
                # Set new checkpoint at best spot
                starting_position = state.current_position
                # Update the reward left to reach goal
                current_max_possible_reward -= state.total_reward
                start_reward += state.total_reward
                run_info.prev_reward += state.total_reward
            end
        catch e
            # Task is solved
            if isa(e, PyCall.PyError)
                has_solved_task = environment.env.done
                push!(try_data["iterations"], Dict(
                    :initial_position => initial_position,
                    :iterations => run_info.iterations,
                    :runtime => time() - iter_start_time,
                    :final_grammar => repr(grammar),
                ))
                break
            else
                # print(e, catch_backtrace())
                rethrow(e)
            end
        end

        push!(try_data["iterations"], Dict(
            :initial_position => initial_position,
            :iterations => run_info.iterations,
            :runtime => time() - iter_start_time,
            :final_grammar => repr(grammar),
        ))
    end

    try_data["runtime"] = (time() - start_time)
    try_data["mined_fragments"] = map(fragments_history) do (t, fragments)
        Dict(:time => t, :fragments => repr(fragments))
    end
    try_data["checkpoint_times"] = starting_times
    try_data["used_fragments"] = map(used_fragments) do (t, fragment)
        Dict(:time => t, :fragment => repr(fragment))
    end
    try_data["generated_programs"] = map(generated_programs) do (t, p)
        Dict(:time => t, :program => repr(p))
    end
    try_data["evaluated_programs"] = map(evaluated_programs) do (t, r, p)
        Dict(:time => t, :reward => r, :program => repr(p))
    end
    try_data["specification_config"] = specification_config
    try_data["frangel_config"] = frangel_config
    try_data["solved"] = has_solved_task

    return try_data
end

"""
    runfrangel_experiment(grammar_config::MinecraftGrammarConfiguration, experiment_configuration::ExperimentConfiguration, worlds::Dict{Int, String}, frangel_seeds::Vector{Int},
        frangel_config::FrAngelConfig, specification_config::SpecificationConfiguration)

Runs FrAngel for all provided `worlds` and `frangel_seeds` based on provided configurations. For each seed combination of worlds and frangel_seed, it runs the experiment `number_of_runs` times and saves the data in a JSON file.
"""
function run_frangel_experiments(;
    grammar_config::MinecraftGrammarConfiguration,
    experiment_configuration::ExperimentConfiguration,
    worlds::Dict{Int, String},
    frangel_seeds::Vector{Int},
    frangel_config::FrAngelConfig,
    specification_config::SpecificationConfiguration,
    create_iterator::Function = create_iterator_frangel,
)
    # Have some joy in life :)
    print_logo()

    # For each world seed run an experiment
    for (world_seed, world_description) in worlds
        # Reset environment to the new seed
        environment.settings[:seed] = world_seed
        reset_env(environment)

        tries_data = []
        for frangel_seed in frangel_seeds

            Random.seed!(frangel_seed)
            # Run the experiment `number_of_runs` times
            for experiment_try_index in 1:experiment_configuration.number_of_runs
                try
                    println("[$(Dates.Time(Dates.now()))] Running experiment with world_seed=$world_seed and random_seed=$frangel_seed, try=$experiment_try_index")
                    # Run the experiment
                    try_output = run_frangel_once(
                        grammar_config=grammar_config,
                        frangel_config=frangel_config,
                        specification_config=specification_config,
                        max_synthesis_runtime=experiment_configuration.max_run_time,
                        create_iterator=create_iterator
                    )

                    if try_output["solved"]
                        printstyled("[$(Dates.Time(Dates.now()))][Seed]: world=$world_seed frangel=$frangel_seed try=$experiment_try_index solved=$(try_output["solved"]) runtime=$(try_output["runtime"])\n", color=:green)
                    else
                        printstyled("[$(Dates.Time(Dates.now()))][Seed]: world=$world_seed frangel=$frangel_seed try=$experiment_try_index solved=$(try_output["solved"]) runtime=$(try_output["runtime"])\n", color=:black)
                    end
                    try_output["try_index"] = experiment_try_index
                    try_output["frangel_seed"] = frangel_seed
                    push!(tries_data, try_output)

                    run_output = deepcopy(try_output)
                    run_output["world_seed"] = world_seed
                    run_output["experiment_description"] = experiment_configuration.experiment_description
                    run_output["grammar"] = repr(grammar_config.minecraft_grammar)
                    run_output["world_description"] = world_description

                    run_output_path = create_experiment_file(directory_path=experiment_configuration.directory_path, experiment_name="world_$(world_seed)_random_$(frangel_seed)")
                    open(run_output_path, "w") do f
                        write(f, json(run_output, 4))
                    end
                catch e
                    println(e, catch_backtrace())
                    println("[$(Dates.Time(Dates.now()))] Error in running the experiment with world_seed=$world_seed frangel_seed=$frangel_seed try_index=$experiment_try_index but we continue")
                end
            end
        end
        # Save the experiment data
        experiment_data = Dict(
            "world_seed" => world_seed,
            "experiment_description" => experiment_configuration.experiment_description,
            "grammar" => repr(grammar_config.minecraft_grammar),
            "tries_data" => tries_data,
            "world_description" => world_description,
        )
        experiment_output_path = create_experiment_file(directory_path=experiment_configuration.directory_path, experiment_name="world_$(world_seed)")
        # Write the data into a JSON
        open(experiment_output_path, "w") do f
            write(f, json(experiment_data, 4))
        end
    end
end