include("../minerl.jl")
include("../experiment_helpers.jl")
include("minecraft_grammar_definition.jl")

using HerbGrammar, HerbSpecification, HerbSearch, HerbInterpret
using Logging
using JSON

# Set up FrAngel to use the test_tuple function for output equality
HerbSearch.test_output_equality(exec_output::Any, out::Any) = test_reward_output_tuple(exec_output, out)

# Set up the Minecraft environment
SEED = 958129
if !(@isdefined environment)
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; seed=SEED, inf_health=true, inf_food=true, disable_mobs=true)
    @debug("Environment initialized")
end

RENDER = true

function create_spec(max_reward::Float64, percentages::Vector{Float64}, require_done::Bool, starting_position::Tuple{Float64, Float64, Float64})::Vector{IOExample}
    spec = Vector{IOExample}()
    for perc in percentages
        spec = push!(spec, IOExample(Dict{Symbol, Any}(:start_pos => starting_position), (perc * max_reward, false)))
    end

    if require_done
        spec = push!(spec, IOExample(Dict{Symbol, Any}(), (max_reward, true)))
    end

    spec
end

RANDOM_SEED = 2

using Random

@kwdef struct SpecificationConfiguration
    max_reward::Float64 = 74.0
    reward_percentages::Vector{Float64} = [0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
    require_done::Bool = false
end

Base.@kwdef struct ExperimentConfiguration
    directory_path::String           # path to the folder where the experiment will be stored 
    experiment_description::String   # name of the experiment
    number_of_runs::Int              # number of runs to run the experiment
    max_run_time::Int                # maximum runtime of one run of an experiment
    render_moves::Bool               #  boolean to render the moves while running
end


""" 
    runfrangel_experiment(grammar_config::MinecraftGrammarConfiguration, frangel_config::FrAngelConfig, specification_config::SpecificationConfiguration, max_synthesis_runtime::Int)

Runs frangel on minerl with the given configurations and returns the runtime, reward over time and if the task was solved
"""
function runfrangel(;
    grammar_config::MinecraftGrammarConfiguration,
    frangel_config::FrAngelConfig,
    specification_config::SpecificationConfiguration,
    max_synthesis_runtime::Int,
)

    grammar, angelic_conditions = grammar_config.minecraft_grammar, grammar_config.angelic_conditions
    current_max_possible_reward = specification_config.max_reward


    start_time = time()
    has_solved_task = false
    reward_over_time = Vector{Tuple{Float64,Float64}}()
    starting_position = environment.start_pos
    start_reward = 0.0

    if environment.env.done
        reset_env(environment)
    else 
        soft_reset_env(environment, environment.start_pos)
    end

    while time() - start_time < max_synthesis_runtime

        rules_min = rules_minsize(grammar)
        symbol_min = symbols_minsize(grammar, rules_min)
        
        problem_specification = create_spec(current_max_possible_reward, specification_config.reward_percentages, specification_config.require_done, starting_position)
        iterator = FrAngelRandomIterator(deepcopy(grammar), :Program, rules_min, symbol_min, max_depth=frangel_config.generation.max_size)
        try
            solution = frangel(problem_specification, frangel_config, angelic_conditions, iterator, rules_min, symbol_min, reward_over_time, start_time, start_reward)    
            if !isnothing(solution)
                state = execute_on_input(grammar, solution, Dict{Symbol, Any}(:start_pos => starting_position)) 
                starting_position = state.current_position
    
                current_max_possible_reward -= state.total_reward # update the reward left
                start_reward += state.total_reward
            end
        catch e
            if isa(e, PyCall.PyError) && environment.env.done
                has_solved_task = true
                break
            else
                rethrow() # TODO: maybe here just print the error such that the experiment can continue
            end
        end       
    end

    # experiment is done, gather data 
    try_data = Dict(
        "runtime" => time() - start_time,
        "reward_over_time" => reward_over_time,
        "solved" => has_solved_task,
        "frangel_config" => frangel_config,
        "specification_config" => specification_config,
    )
    return try_data
end

function runfrangel_experiment_with_different_configs(; 
    grammar_config::MinecraftGrammarConfiguration,
    experiment_configuration::ExperimentConfiguration,
    frangel_configs::Vector{FrAngelConfig},
    seeds::Vector{Int},
    specification_config::SpecificationConfiguration,
)
    # for each world seed run the experiment
    for world_seed in seeds
        experiment_output_path = create_experiment_file(directory_path = experiment_configuration.directory_path, experiment_name = "Seed_$world_seed")
        
        # reset environment to the new seed
        environment.settings[:seed] = world_seed
        reset_env(environment)        
        tries_data = []
        for frangel_config in frangel_configs
            # for each experiment try run the experiment
            Random.seed!(RANDOM_SEED) # seed the random seed the same for each world 
            for experiment_try_index in 1:experiment_configuration.number_of_runs
                try 
                    try_output = runfrangel(
                        grammar_config = grammar_config,
                        frangel_config = frangel_config,
                        specification_config = specification_config,
                        max_synthesis_runtime = experiment_configuration.max_run_time,
                    )
                    if try_output["solved"]
                        printstyled("[Seed]: $world_seed try=$experiment_try_index solved=$(try_output["solved"]) runtime=$(try_output["runtime"])\n", color=:green)
                    else
                        printstyled("[Seed]: $world_seed try=$experiment_try_index solved=$(try_output["solved"]) runtime=$(try_output["runtime"])\n", color=:black)
                    end
                    try_output["try_index"] = experiment_try_index
                    push!(tries_data, try_output)
                catch e
                    @error e
                        println("Error in running the experiment with world_seed=$world_seed but we continue")
                end
            end
        end
        experiment_data = Dict(
            "world_seed" => world_seed,
            "experiment_description" => experiment_configuration.experiment_description,
            "grammar" => repr(grammar_config.minecraft_grammar),
            "tries_data" => tries_data
        )
        # write json to the experiment path
        open(experiment_output_path, "w") do f
            write(f, json(experiment_data, 4))
        end
    end
end
HerbSearch.print_logo_frangel()
minerl_grammar_config::MinecraftGrammarConfiguration = get_minecraft_grammar()

function run_different_configs(; experiment_name::String, experiment_description::String, frangel_configs::Vector{FrAngelConfig})
    @time runfrangel_experiment_with_different_configs(
        grammar_config = minerl_grammar_config, 
        experiment_configuration=ExperimentConfiguration(
            directory_path="src/minecraft/experiments/frangel/$experiment_name",
            experiment_description=experiment_description,
            number_of_runs=3,
            max_run_time=200,
            render_moves=RENDER
        ),
        seeds = GLOBAL_SEEDS_FOR_EXPERIMENTS,
        frangel_configs=frangel_configs,
        specification_config=SpecificationConfiguration(),
    )
end

function frangel_experiment_fragment_chance()
    fragment_chances=[0.2, 0.4, 0.6, 0.8]
    max_time_frangel = 20.0
    frangel_configs::Vector{FrAngelConfig} = Vector{FrAngelConfig}()
    for fragment_prob in fragment_chances
        frangel_config = FrAngelConfig(
            max_time=max_time_frangel,
            generation=FrAngelConfigGeneration(use_fragments_chance=fragment_prob, use_angelic_conditions_chance=0, max_size=40),
        )
        push!(frangel_configs, frangel_config)
    end

    run_different_configs(
        experiment_name="experiment_different_use_fragement_probabilities",
        experiment_description="Experiment with different mining fragments probabilities",
        frangel_configs=frangel_configs,
    )
end

function frangel_experiment_max_time()
    fragement_chance = 0.4
    frangel_configs::Vector{FrAngelConfig} = Vector{FrAngelConfig}()
    max_times_frangel = [5, 10, 20, 30]
    for max_time in max_times_frangel
        frangel_config = FrAngelConfig(
            max_time=max_time,
            generation=FrAngelConfigGeneration(use_fragments_chance=fragement_chance, use_angelic_conditions_chance=0, max_size=40),
        )
        push!(frangel_configs, frangel_config)
    end

    run_different_configs(
        experiment_name="experiment_different_frangel_max_time",
        experiment_description="Experiment with different maximum running time for frangel synthesis cycle",
        frangel_configs=frangel_configs,
    )
end

function frangel_experiment_with_different_mutation_probabilities()
    fragement_chance = 0.4
    max_time = 20
    mutation_probabilities = [0, 0.1, 0.2, 0.4, 0.5]

    frangel_configs::Vector{FrAngelConfig} = Vector{FrAngelConfig}()
    for mutation_probability in mutation_probabilities
        frangel_config = FrAngelConfig(
            max_time=max_time,
            generation=FrAngelConfigGeneration(
                gen_similar_prob_new=mutation_probability,
                use_fragments_chance=fragement_chance, 
                use_angelic_conditions_chance=0
            )
        )
        push!(frangel_configs, frangel_config)
    end

    run_different_configs(
        experiment_name="experiment_differrent_probabilities_of_mutating_programs",
        experiment_description="Experiment with different probabilities of mutation when generating new programs",
        frangel_configs=frangel_configs,
    )
end


function frangel_experiment_with_different_use_entire_fragment_probabilities()
    max_time = 20
    use_entire_fragement_chances = [0, 0.2, 0.4, 0.6, 0.8]

    frangel_configs::Vector{FrAngelConfig} = Vector{FrAngelConfig}()
    for fragment_chance in use_entire_fragement_chances
        frangel_config = FrAngelConfig(
            max_time=max_time,
            generation=FrAngelConfigGeneration(
                use_entire_fragment_chance=fragment_chance, 
                use_angelic_conditions_chance=0
            )
        )
        push!(frangel_configs, frangel_config)
    end

    run_different_configs(
        experiment_name="experiment_differrent_probabilities_use_entire_fragments_chance",
        experiment_description="Experiment with different probabilities of reusing an entire fragement",
        frangel_configs=frangel_configs,
    )
end

# frangel_second_experiment()
# frangel_experiment_fragement_chance()
# frangel_experiment_with_different_mutation_probabilities()
# frangel_experiment_with_different_use_entire_fragment_probabilities()
frangel_experiment_with_different_mutation_probabilities()