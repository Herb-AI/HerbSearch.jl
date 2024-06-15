include("minerl.jl")
include("minecraft_grammar_definition.jl")
include("experiment_helpers.jl")
include("utils.jl")

using HerbSearch
using Logging
disable_logging(LogLevel(1))

# Set up FrAngel to use the test_tuple function for output equality
HerbSearch.test_output_equality(exec_output::Any, out::Any) = test_reward_output_tuple(exec_output, out)

WORLDS = Dict(
    958129 => "Relatively flat. Some trees. Small cave opening.",
    95812 => "Big hole between start and goal. Small hills. Many trees.",
    11248956 => "Big cave forward. Reward increases when entering cave. Goal not in cave.",
    6354 => "Many trees. Small hill. Ocean on the way and goal on island",
    999999 => "Desert. No obstacles."
)

RANDOM_GENERATOR_SEEDS = [1234, 4561, 1789, 8615, 1118, 9525, 2541, 9156]

# Set here to work as a global variable - used in other files
RENDER = false

# Constants
RUNS_PER_SETUP = 1
MAX_ALLOWED_TIME_PER_RUN = 300
MAX_ALLOWED_TIME_PER_ITERATION = 40

DEFAULT_CONFIG = FrAngelConfig(
    max_time = MAX_ALLOWED_TIME_PER_ITERATION,
    compare_programs_by_length = true,
    generation = FrAngelConfigGeneration(
        max_size = 40,
        use_fragments_chance = 0.5,
        use_angelic_conditions_chance = 0.2,
    ),
    angelic = FrAngelConfigAngelic(
        boolean_expr_max_size = 6,
        max_execute_attempts = 4,
    )
)

# Set up the Minecraft environment
if !(@isdefined environment)
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; seed=958129, inf_health=true, inf_food=true, disable_mobs=true)
    @debug("Environment initialized")
end

experiments_to_run = [0, 1, 2, 3, 4]

if 0 in experiments_to_run
    @time run_frangel_experiments(
        grammar_config=get_minecraft_grammar_config(),
        experiment_configuration=ExperimentConfiguration(
            directory_path="experiment_results/base",
            experiment_description="Base setup - used to compare with other experiments.",
            number_of_runs=RUNS_PER_SETUP,
            max_run_time=MAX_ALLOWED_TIME_PER_RUN,
            render_moves=RENDER
        ),
        worlds=WORLDS,
        frangel_seeds=RANDOM_GENERATOR_SEEDS,
        specification_config=SpecificationConfiguration(),
        frangel_config=DEFAULT_CONFIG
    )
end

if 1 in experiments_to_run
    for reward_percentages in [[0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9], [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9], [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9], [0.4, 0.5, 0.6, 0.7, 0.8, 0.9]]
        @time run_frangel_experiments(
            grammar_config=get_minecraft_grammar_config(),
            experiment_configuration=ExperimentConfiguration(
                directory_path="experiment_results/reward_percentages_$(reward_percentages)",
                experiment_description="Different beginning reward checkpoints - In this experiment, the smallest reward checkpoints are increased and decreased, such that the length of the pure exploration part of the FrAngel algorithm could be increased or decreased and eventually provide different quality fragments that can be explored after that. ",
                number_of_runs=RUNS_PER_SETUP,
                max_run_time=MAX_ALLOWED_TIME_PER_RUN,
                render_moves=RENDER
            ),
            worlds=WORLDS,
            frangel_seeds=RANDOM_GENERATOR_SEEDS,
            specification_config=SpecificationConfiguration(reward_percentages=reward_percentages),
            frangel_config=DEFAULT_CONFIG
        )
    end
end

HerbSearch.should_mine_for_symbol(symbol::Symbol) = symbol != :Program && symbol != :Blocks

if 2 in experiments_to_run
    @time run_frangel_experiments(
        grammar_config=get_minecraft_grammar_config(),
        experiment_configuration=ExperimentConfiguration(
            directory_path="experiment_results/without_program_and_block_fragments",
            experiment_description="Limited fragment symbols - In this experiment, there are no fragments of symbols Program and Blocks.",
            number_of_runs=RUNS_PER_SETUP,
            max_run_time=MAX_ALLOWED_TIME_PER_RUN,
            render_moves=RENDER
        ),
        worlds=WORLDS,
        frangel_seeds=RANDOM_GENERATOR_SEEDS,
        specification_config=SpecificationConfiguration(),
        frangel_config=DEFAULT_CONFIG
    )
end

HerbSearch.should_mine_for_symbol(symbol::Symbol) = true

create_iterator_experimental(grammar::AbstractGrammar, symbol::Symbol, rules_min::Vector{UInt8}, symbol_min::Dict{Symbol,UInt8}, frangel_config::FrAngelConfig) = ExperimentalRandomIterator(grammar, symbol, rules_min, symbol_min, length(grammar))

if 3 in experiments_to_run
    @time run_frangel_experiments(
        grammar_config=get_minecraft_grammar_config(),
        experiment_configuration=ExperimentConfiguration(
            directory_path="experiment_results/experimental_random_iterator",
            experiment_description="Experimental random iterator - In this experiment, the random iterator is modified to give a higher probability to basic rules used in generation less frequently.",
            number_of_runs=RUNS_PER_SETUP,
            max_run_time=MAX_ALLOWED_TIME_PER_RUN,
            render_moves=RENDER
        ),
        worlds=WORLDS,
        frangel_seeds=RANDOM_GENERATOR_SEEDS,
        specification_config=SpecificationConfiguration(),
        frangel_config=DEFAULT_CONFIG
    )
end

if 4 in experiments_to_run
    for use_f_chance in [0.3, 0.5]
        for gen_sim_new_chance in [0.25, 0.5, 0.75]
            @time run_frangel_experiments(
                grammar_config=get_minecraft_grammar_config(),
                experiment_configuration=ExperimentConfiguration(
                    directory_path="experiment_results/fragment_usage_chance_$(use_f_chance)_gen_sim_new_chance_$(gen_sim_new_chance)",
                    experiment_description="Fragments usage and modification probability - In this experiment, the probability of using fragments and the probability of modifiying fragments are changed.",
                    number_of_runs=RUNS_PER_SETUP,
                    max_run_time=MAX_ALLOWED_TIME_PER_RUN,
                    render_moves=RENDER
                ),
                worlds=WORLDS,
                frangel_seeds=RANDOM_GENERATOR_SEEDS,
                specification_config=SpecificationConfiguration(),
                frangel_config=FrAngelConfig(
                    max_time = MAX_ALLOWED_TIME_PER_ITERATION,
                    compare_programs_by_length = true,
                    generation = FrAngelConfigGeneration(
                        max_size = 40,
                        gen_similar_prob_new = gen_sim_new_chance,
                        use_fragments_chance = use_f_chance,
                        use_angelic_conditions_chance = 0.2,
                    ),
                    angelic = FrAngelConfigAngelic(
                        boolean_expr_max_size = 6,
                        max_execute_attempts = 4,
                    )
                )
            )
        end
    end
end