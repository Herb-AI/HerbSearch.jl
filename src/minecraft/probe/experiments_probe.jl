include("../minerl.jl")
include("../experiment_helpers.jl")

using HerbGrammar, HerbSpecification, HerbSearch, HerbConstraints
using Logging
using JSON
using Random 

RENDER_MOVES = false # configure to render moves or not when training

minerl_grammar = @pcsgrammar begin
    1:best_program = []
    1:SEQ = [best_program; MOVES]
    1:MOVES = [MOVES; ACT]
    1:MOVES = [ACT]
    8:DIR = 0b0001 | 0b0010 | 0b0100 | 0b1000 | 0b0101 | 0b1001 | 0b0110 | 0b1010 # forward | back | left | right | forward-left | forward-right | back-left | back-right
    1:ACT = (TIMES, Dict("move" => DIR, "sprint" => 1, "jump" => 1))
    6:TIMES = 5 | 10 | 25 | 50 | 75 | 100
end

function assert_grammar_is_uniform(grammar::ContextSensitiveGrammar)
    @assert all(prob -> prob == grammar.log_probabilities[begin], grammar.log_probabilities)
end
assert_grammar_is_uniform(minerl_grammar)

# make sure the probabilities are equal 
default_environment_name = "MineRLNavigateDenseProgSynth-v0"
default_seed = 4123
if !(@isdefined environment)
    global environment = create_env(default_environment_name; seed=default_seed, inf_health=true, inf_food=true, disable_mobs=true)
end

#  overwrite the evaluate trace function
HerbSearch.evaluate_trace(prog::RuleNode, grammar::ContextSensitiveGrammar) = evaluate_trace_minerl(prog, grammar, environment, RENDER_MOVES)
HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_prob(rule_index, grammar)

Base.@kwdef struct ExperimentConfiguration
    directory_path::String           # path to the folder where the experiment will be stored 
    experiment_description::String  # name of the experiment
    number_of_runs::Int      # number of runs to run the experiment
    max_run_time::Int       # maximum runtime of one run of an experiment
    render_moves::Bool      # boolean to render the moves while running
end

struct MineRLConfiguration 
    seed::Int
    environment_name::String
end

function run_first_experiment(; seeds::Vector{Int}, grammar::ContextSensitiveGrammar, experiment_configuration::ExperimentConfiguration, cycle_lengths)
    starting_time = time()
    for seed in seeds
        # create the output file
        output_file_path = create_experiment_file(directory_path = experiment_configuration.directory_path, experiment_name = "Seed_$seed")
        minerl_configuration = MineRLConfiguration(seed, default_environment_name)
        all_data = []
        for cycle_length in cycle_lengths
            tries_data = []
            for i in 1:experiment_configuration.number_of_runs

                environment.settings[:seed] = seed
                reset_env(environment)

                assert_grammar_is_uniform(grammar)
                deep_copied_grammar = deepcopy(grammar)

                iter = HerbSearch.GuidedSearchTraceIterator(deep_copied_grammar, :SEQ)
                program, probe_meta_data = probe(Vector{Trace}(), iter, max_time=experiment_configuration.max_run_time, cycle_length=cycle_length)

                probe_meta_data[:try_index] = i
                probe_meta_data[:cycle_length] = cycle_length
                push!(tries_data, probe_meta_data)
                @info "seed=$seed length=$cycle_length try=$i solved=$(probe_meta_data[:solved]) time=$(probe_meta_data[:total_time])"
            end
            push!(all_data, Dict("cycle_length_$cycle_length" => tries_data))
        end
        experiment_data = Dict(
            :minerl_configuration => minerl_configuration,
            :experiment_configuration => experiment_configuration,
            :data => all_data
        )
        # write the experiment results to the file path
        open(output_file_path, "w") do f
            write(f, json(experiment_data, 4))
        end
        @info "Finished experiment for seed=$seed"
        @info "Current running time : $(time() - starting_time) seconds"
    end
end

function run_first_experiment_configured()
    cycle_lengths_range = 5:8 
    run_first_experiment(
        seeds=GLOBAL_SEEDS_FOR_EXPERIMENTS, 
        grammar=minerl_grammar,
        experiment_configuration=ExperimentConfiguration(
            directory_path="src/minecraft/experiments/probe/experiment_cycles/",
            experiment_description="Experiment with different cycle lengths",
            number_of_runs=3,
            max_run_time=300,
            render_moves=RENDER_MOVES
        ),
        cycle_lengths=cycle_lengths_range)
end

assert_grammar_is_uniform(minerl_grammar)

function run_second_experiment(; seeds::Vector{Int}, grammar::ContextSensitiveGrammar, experiment_configuration::ExperimentConfiguration, cycle_length, random_probability)
    starting_time = time()
    for seed in seeds
        # create the output file
        output_file_path = create_experiment_file(directory_path = experiment_configuration.directory_path, experiment_name = "Seed_$seed")
        minerl_configuration = MineRLConfiguration(seed, default_environment_name)
        tries_data = []
        for i in 1:experiment_configuration.number_of_runs

            environment.settings[:seed] = seed
            reset_env(environment)

            assert_grammar_is_uniform(grammar)
            deep_copied_grammar = deepcopy(grammar)

            iter = HerbSearch.AlternatingRandomGuidedSearchIterator(deep_copied_grammar, :SEQ, random_moves_probability=random_probability)
            program, probe_meta_data = probe(Vector{Trace}(), iter, max_time=experiment_configuration.max_run_time, cycle_length=cycle_length)

            probe_meta_data[:try_index] = i
            probe_meta_data[:cycle_length] = cycle_length
            probe_meta_data[:random_probability] = random_probability
            push!(tries_data, probe_meta_data)
            @info "seed=$seed length=$cycle_length try=$i solved=$(probe_meta_data[:solved]) time=$(probe_meta_data[:total_time])"
        end
        experiment_data = Dict(
            :minerl_configuration => minerl_configuration,
            :experiment_configuration => experiment_configuration,
            :data => tries_data
        )
        # write the experiment results to the file path
        open(output_file_path, "w") do f
            write(f, json(experiment_data, 4))
        end
        @info "Finished experiment for seed=$seed"
        @info "Current running time : $(time() - starting_time) seconds"
    end
end

function run_second_experiment_configured(;random_probability,file)
    Random.seed!(1234)
    run_second_experiment(
        seeds=GLOBAL_SEEDS_FOR_EXPERIMENTS, 
        grammar=minerl_grammar,
        experiment_configuration=ExperimentConfiguration(
            directory_path=file,
            experiment_description="Experiment with different cycle lengths",
            number_of_runs=3,
            max_run_time=300,
            render_moves=RENDER_MOVES
        ),
        cycle_length=5,
        random_probability=random_probability
    )
end

function run_alternative_random_experiments()
    debug_logger = ConsoleLogger(stdout, Logging.Info)
    with_logger(debug_logger) do # Enable the debug logger locally
        run_second_experiment_configured(random_probability = 0.3, file="src/minecraft/experiments/probe/experiment_alternating_random_0.3")
        run_second_experiment_configured(random_probability = 0.5, file="src/minecraft/experiments/probe/experiment_alternating_random_0.5")
        run_second_experiment_configured(random_probability = 1,   file="src/minecraft/experiments/probe/experiment_alternating_random_1")
    end
end

HerbSearch.print_logo_probe()
run_alternative_random_experiments()
