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
# Set here to work as a global variable - used in other files
RENDER = true

# Set up the Minecraft environment
if !(@isdefined environment)
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; seed=958129, inf_health=true, inf_food=true, disable_mobs=true)
    @debug("Environment initialized")
end

############################################
### Main body -> run FrAngel experiments ###
############################################

run_experiment = 3

# Experiment #0 => Showcase "quantity" changes of FrAngel configuration
# Try different max_time and max_size values
# We expect more time and more size => more complex programs
# Result: More size does correlate with more complex programs, but time is inversely proportional! Initially suprising, but makes sense after thinking about it more.
if run_experiment == 0
    for seed in [958129, 6354]
        for max_t in [10, 20, 30, 40]
            for max_s in [10, 20, 40, 60]
                @time run_frangel_experiments(
                    grammar_config=get_minecraft_grammar(),
                    experiment_configuration=ExperimentConfiguration(
                        directory_path="HerbSearch/src/minecraft/experiment_results/experiment_0_2",
                        experiment_description="Experiment #0_2 => Showcase \"quantity\" changes of FrAngel configuration",
                        number_of_runs=5,
                        max_run_time=300,
                        render_moves=RENDER # Toggle if Minecraft should be rendered
                    ),
                    world_seeds=[seed], # Seed for MineRL world environment
                    frangel_seeds=[1234], # Seed for FrAngel
                    specification_config=SpecificationConfiguration(),
                    frangel_config=FrAngelConfig(max_time=max_t, verbose_level=0,
                        generation=FrAngelConfigGeneration(use_fragments_chance=0.8, use_angelic_conditions_chance=0, max_size=max_s))
                )
            end
        end
    end
end

# Experiment #1 => Showcase "quality" changes of FrAngel configuration
# Try different use_fragments_chance, use_entire_fragment_chance, and gen_similar_prob_new values
if run_experiment == 1
    for use_f_chance in [0.3, 0.65, 0.8, 0.9]
        for use_entire_f_chance in [0.3, 0.65, 0.9]
            for gen_sim_new_chance in [0, 0.25, 0.5, 0.75]
                @time run_frangel_experiments(
                    grammar_config=get_minecraft_grammar(),
                    experiment_configuration=ExperimentConfiguration(
                        directory_path="HerbSearch/src/minecraft/experiment_results/experiment_1",
                        experiment_description="Experiment #1 => Showcase \"quality\" changes of FrAngel configuration",
                        number_of_runs=5,
                        max_run_time=300,
                        render_moves=RENDER # Toggle if Minecraft should be rendered
                    ),
                    world_seeds=[958129], # Seed for MineRL world environment
                    frangel_seeds=[1234], # Seed for FrAngel
                    specification_config=SpecificationConfiguration(),
                    frangel_config=FrAngelConfig(max_time=10, verbose_level=0,
                        generation=FrAngelConfigGeneration(
                            use_fragments_chance=use_f_chance,
                            use_entire_fragment_chance=use_entire_f_chance,
                            gen_similar_prob_new=gen_sim_new_chance,
                            use_angelic_conditions_chance=0, max_size=40))
                )
            end
        end
    end
end

# Experiment #2 => Tweak FrAngel's implementation to remember more complex programs instead
if run_experiment == 2
    for tune_config in [false, true]
        for store_simpler_programs in [false, true]
            frangel_config = FrAngelConfig(max_time=10, generation=FrAngelConfigGeneration(use_angelic_conditions_chance=0), store_simpler_programs=store_simpler_programs)
            if tune_config
                frangel_config = FrAngelConfig(max_time=10, store_simpler_programs=store_simpler_programs,
                    generation=FrAngelConfigGeneration(use_fragments_chance=0.3, use_entire_fragment_chance=0.3, gen_similar_prob_new=0.0, use_angelic_conditions_chance=0, max_size=60))
            end
            @time run_frangel_experiments(
                grammar_config=get_minecraft_grammar(),
                experiment_configuration=ExperimentConfiguration(
                    directory_path="HerbSearch/src/minecraft/experiment_results/experiment_2",
                    experiment_description="Experiment #2 => Tweak FrAngel's implementation to remember more complex programs instead",
                    number_of_runs=5,
                    max_run_time=300,
                    render_moves=RENDER # Toggle if Minecraft should be rendered
                ),
                world_seeds=collect(keys(WORLDS)), # Seed for MineRL world environment
                frangel_seeds=[1234], # Seed for FrAngel
                specification_config=SpecificationConfiguration(),
                frangel_config=frangel_config)
        end
    end
end

# Experiment #3 => Tweak FrAngel's grammar to give preference for recursive rulenodes
if run_experiment == 3
    for recursion_depth in 2:4
        grammar = get_minecraft_grammar(recursion_depth)
        @time run_frangel_experiments(
            grammar_config=grammar,
            experiment_configuration=ExperimentConfiguration(
                directory_path="HerbSearch/src/minecraft/experiment_results/experiment_3",
                experiment_description="Experiment #3 => Tweak FrAngel's grammar to give preference for recursive rulenodes",
                number_of_runs=5,
                max_run_time=300,
                render_moves=RENDER # Toggle if Minecraft should be rendered
            ),
            world_seeds=collect(keys(WORLDS)), # Seed for MineRL world environment
            frangel_seeds=[1234], # Seed for FrAngel
            specification_config=SpecificationConfiguration(),
            frangel_config=FrAngelConfig(max_time=10, generation=FrAngelConfigGeneration(use_angelic_conditions_chance=0), recursion_depth=recursion_depth))
    end
end