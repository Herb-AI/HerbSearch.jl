include("minerl.jl")
include("rewards_utils.jl")
include("minecraft_grammar_definition.jl")
include("experiment_helpers.jl")

using HerbGrammar, HerbSpecification, HerbSearch, HerbInterpret, HerbCore
using Logging, JSON, PyCall
using Random, Dates
disable_logging(LogLevel(1))

# Configuration

WORLD_DESCRIPTIONS = Dict(
    958129 => "Relatively flat. Some trees. Cave opening.",
    95812 => "Big hole between start and goal. Small hills. Trees.",
    11248956 => "Big cave forward. Reward increases when entering cave. Goal not in cave.",
    6354 => "Many trees. Small hill.",
    999999 => "Desert. No obstacles."
)

RANDOM_GENERATOR_SEEDS = [1234, 4561, 1789, 8615, 1118, 9525, 2541, 9156]

MAX_ALLOWED_TIME_PER_RUN = 300 # in seconds

TIMES_PER_SETUP = 1
MAX_ALLOWED_TIME_PER_ITERATION = 40 # in seconds

MAX_REWARD = 74.0

SPEC_PERCENTAGES = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]

RENDER = false

CONFIG = FrAngelConfig(
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

# Setup

## Set up the Minecraft environment
if !(@isdefined environment)
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; inf_health=true, inf_food=true, disable_mobs=true)
    println("Environment initialized")
end

## Set up FrAngel to use the test_tuple function for output equality
HerbSearch.test_output_equality(exec_output::Any, out::Any) = test_reward_output_tuple(exec_output, out)


function run_experiment_base()
    println("Running experiment")
    dir = "experiments/experiment_base"
    mkpath(dir)

    experiment_start_time = time()
    
    for world_seed in keys(WORLD_DESCRIPTIONS)
        println("[$(Dates.Time(Dates.now()))] >Running experiment for world seed $world_seed")

        for random_generator_seed in RANDOM_GENERATOR_SEEDS
            println("[$(Dates.Time(Dates.now()))] >>Running experiment for random generator seed $random_generator_seed")

            for i in 1:TIMES_PER_SETUP
                println("[$(Dates.Time(Dates.now()))] >>>Running experiment for try $i")

                try
                    result = run_once(world_seed, random_generator_seed)

                    file_path = "$dir/$(world_seed)_$(random_generator_seed)_$i.json"
                    file = open(file_path, "w")
                    JSON.print(file, result, 4)
                    close(file)
                catch e
                    println("Error: $e")
                end
            end
            # todo create additional files for each random generator seed
        end
        # todo create additional files for each world seed
    end
    println("Expertiment took: ", (time() - experiment_start_time))
    # todo create additional files for the whole experiment
end

function run_experiment_1()
    println("Running experiment")
    dir = "experiments/experiment_1"
    mkpath(dir)

    experiment_start_time = time()
    
    for world_seed in keys(WORLD_DESCRIPTIONS)
        println("[$(Dates.Time(Dates.now()))] >Running experiment for world seed $world_seed")

        for random_generator_seed in RANDOM_GENERATOR_SEEDS
            println("[$(Dates.Time(Dates.now()))] >>Running experiment for random generator seed $random_generator_seed")

            for i in 1:TIMES_PER_SETUP
                println("[$(Dates.Time(Dates.now()))] >>>Running experiment for try $i")

                try
                    result = run_once(world_seed, random_generator_seed)

                    file_path = "$dir/$(world_seed)_$(random_generator_seed)_$i.json"
                    file = open(file_path, "w")
                    JSON.print(file, result, 4)
                    close(file)
                catch e
                    println("Error: $e")
                end
            end
            # todo create additional files for each random generator seed
        end
        # todo create additional files for each world seed
    end
    println("Expertiment took: ", (time() - experiment_start_time))
    # todo create additional files for the whole experiment
end


function run_experiment_2()
    println("Running experiment")
    dir = "experiments/experiment_2"
    mkpath(dir)

    experiment_start_time = time()
    
    for world_seed in keys(WORLD_DESCRIPTIONS)
        println("[$(Dates.Time(Dates.now()))] >Running experiment for world seed $world_seed")

        for random_generator_seed in RANDOM_GENERATOR_SEEDS
            println("[$(Dates.Time(Dates.now()))] >>Running experiment for random generator seed $random_generator_seed")

            for i in 1:TIMES_PER_SETUP
                println("[$(Dates.Time(Dates.now()))] >>>Running experiment for try $i")

                try
                    result = run_once(world_seed, random_generator_seed)

                    file_path = "$dir/$(world_seed)_$(random_generator_seed)_$i.json"
                    file = open(file_path, "w")
                    JSON.print(file, result, 4)
                    close(file)
                catch e
                    println("Error: $e")
                end
            end
            # todo create additional files for each random generator seed
        end
        # todo create additional files for each world seed
    end
    println("Expertiment took: ", (time() - experiment_start_time))
    # todo create additional files for the whole experiment
end

function run_experiment_3()
    println("Running experiment")
    dir = "experiments/experiment_3"
    mkpath(dir)

    experiment_start_time = time()
    
    for world_seed in keys(WORLD_DESCRIPTIONS)
        println("[$(Dates.Time(Dates.now()))] >Running experiment for world seed $world_seed")

        for random_generator_seed in RANDOM_GENERATOR_SEEDS
            println("[$(Dates.Time(Dates.now()))] >>Running experiment for random generator seed $random_generator_seed")

            for i in 1:TIMES_PER_SETUP
                println("[$(Dates.Time(Dates.now()))] >>>Running experiment for try $i")

                try
                    result = run_once(world_seed, random_generator_seed)

                    file_path = "$dir/$(world_seed)_$(random_generator_seed)_$i.json"
                    file = open(file_path, "w")
                    JSON.print(file, result, 4)
                    close(file)
                catch e
                    println("Error: $e")
                end
            end
            # todo create additional files for each random generator seed
        end
        # todo create additional files for each world seed
    end
    println("Expertiment took: ", (time() - experiment_start_time))
    # todo create additional files for the whole experiment
end

function run_experiment_5()
    println("Running experiment")
    dir = "experiments/experiment_5"
    mkpath(dir)

    experiment_start_time = time()
    
    for world_seed in keys(WORLD_DESCRIPTIONS)
        println("[$(Dates.Time(Dates.now()))] >Running experiment for world seed $world_seed")

        for random_generator_seed in RANDOM_GENERATOR_SEEDS
            println("[$(Dates.Time(Dates.now()))] >>Running experiment for random generator seed $random_generator_seed")

            for i in 1:TIMES_PER_SETUP
                println("[$(Dates.Time(Dates.now()))] >>>Running experiment for try $i")

                try
                    result = run_once5(world_seed, random_generator_seed)

                    file_path = "$dir/$(world_seed)_$(random_generator_seed)_$i.json"
                    file = open(file_path, "w")
                    JSON.print(file, result, 4)
                    close(file)
                catch e
                    println("Error: $e")
                end
            end
            # todo create additional files for each random generator seed
        end
        # todo create additional files for each world seed
    end
    println("Expertiment took: ", (time() - experiment_start_time))
    # todo create additional files for the whole experiment
end

mutable struct IterationResult
    initial_position::Tuple{Float64, Float64, Float64}
    reward_over_time::Vector{Tuple{Float64, Float64}}
    fragments_used::Vector{Float64}
    fragments_mined::Vector{Float64}
    iterations::Int
    time_taken::Float64
    final_program::String
    final_grammar::Vector{String}
    reward_checkpoints::Vector{Float64}
end

mutable struct RunResult
    found_solution::Bool
    total_time::Float64
    reward_over_time::Vector{Tuple{Float64, Float64}}
    iteration_switch_times::Vector{Float64}

    iterations_results::Vector{IterationResult}
end

function run_once(world_seed, random_generator_seed)
    push!(environment.settings, :seed => world_seed)
    reset_env(environment)

    if (environment.env.done)
        println("Environment done")
        reset_env(environment)
        println("Reset again")
    end

    @assert !environment.env.done

    Random.seed!(random_generator_seed)

    start_time = time()
    reward_over_time::Vector{Tuple{Float64, Float64}} = Vector{Tuple{Float64, Float64}}()
    iteration_switch_times::Vector{Float64} = Vector{Float64}()
    iterations_results::Vector{IterationResult} = Vector{IterationResult}()
    initial_position = environment.start_pos

    left_reward = MAX_REWARD
    start_reward = 0.0

    grammar_config = get_minecraft_grammar_config()
    grammar, angelic_conditions = grammar_config.minecraft_grammar, grammar_config.angelic_conditions

    rules_min = rules_minsize(grammar)
    symbol_min = symbols_minsize(grammar, rules_min)

    while time() - start_time < MAX_ALLOWED_TIME_PER_RUN 
        iter_start_time = time()
        iter_grammar = deepcopy(grammar)
        spec = create_spec(left_reward, SPEC_PERCENTAGES, false, initial_position)
        reward_checkpoints = SPEC_PERCENTAGES .* left_reward
        iter_rules_min = deepcopy(rules_min)
        iter_symbol_min = deepcopy(symbol_min)

        iter_reward_over_time::Vector{Tuple{Float64, Float64}} = Vector{Tuple{Float64, Float64}}()
        iter_fragments_used = Vector{Float64}()
        iter_fragments_mined = Vector{Float64}()

        iterator = FrAngelRandomIterator(iter_grammar, :Program, iter_rules_min, iter_symbol_min, max_depth=CONFIG.generation.max_size)

        solution = nothing
        iterations = 0
        try
            (solution, iterations) = frangel(spec, CONFIG, angelic_conditions, iterator, iter_rules_min, iter_symbol_min, reward_over_time, start_reward, start_time, iter_reward_over_time, iter_fragments_used, iter_fragments_mined)   
            
            iter_final_program = isnothing(solution) ? "nothing" : string(rulenode2expr(solution, iter_grammar))
            push!(iterations_results, IterationResult(deepcopy(initial_position), iter_reward_over_time, iter_fragments_used, iter_fragments_mined, iterations, time() - iter_start_time, iter_final_program, grammar_to_list(iter_grammar), reward_checkpoints))
            if !isnothing(solution)
                state = execute_on_input(grammar, solution, Dict{Symbol, Any}(:start_pos => initial_position)) 
                initial_position = state.current_position
    
                left_reward -= state.total_reward
                start_reward += state.total_reward
            end
            push!(iteration_switch_times, time() - start_time)
        catch ex
            if isa(ex, PyCall.PyError) && environment.env.done
                iter_final_program = isnothing(solution) ? "nothing" : string(rulenode2expr(solution, grammar))
                push!(iterations_results, IterationResult(deepcopy(initial_position), iter_reward_over_time, iter_fragments_used, iter_fragments_mined, iterations, time() - iter_start_time, iter_final_program, grammar_to_list(iter_grammar), reward_checkpoints))

                return RunResult(true, time() - start_time, reward_over_time, iteration_switch_times, iterations_results)
            elseif isa(ex, InterruptException)
                println("Stopping...")
                throw(ex)
            else
                iter_final_program = "nothing"
                push!(iterations_results, IterationResult(deepcopy(initial_position), iter_reward_over_time, iter_fragments_used, iter_fragments_mined, iterations, time() - iter_start_time, iter_final_program, grammar_to_list(iter_grammar), reward_checkpoints))
                println("Error")
                showerror(stdout, ex, catch_backtrace())
             
                return RunResult(false, time() - start_time, reward_over_time, iteration_switch_times, iterations_results)
            end
        end       
    end

    return RunResult(false, time() - start_time, reward_over_time, iteration_switch_times, iterations_results)
end

# function run_once4(world_seed, random_generator_seed)
#     push!(environment.settings, :seed => world_seed)
#     reset_env(environment)

#     if (environment.env.done)
#         println("Environment done")
#         reset_env(environment)
#         println("Reset again")
#     end

#     @assert !environment.env.done

#     Random.seed!(random_generator_seed)

#     start_time = time()
#     reward_over_time::Vector{Tuple{Float64, Float64}} = Vector{Tuple{Float64, Float64}}()
#     iteration_switch_times::Vector{Float64} = Vector{Float64}()
#     iterations_results::Vector{IterationResult} = Vector{IterationResult}()
#     initial_position = environment.start_pos

#     left_reward = MAX_REWARD
#     start_reward = 0.0

#     grammar_config = get_minecraft_grammar_config()
#     grammar, angelic_conditions = grammar_config.minecraft_grammar, grammar_config.angelic_conditions

#     rules_min = rules_minsize(grammar)
#     symbol_min = symbols_minsize(grammar, rules_min)

#     while time() - start_time < MAX_ALLOWED_TIME_PER_RUN 
#         iter_start_time = time()
#         iter_grammar = deepcopy(grammar)
#         spec = create_spec(left_reward, SPEC_PERCENTAGES, false, initial_position)
#         reward_checkpoints = SPEC_PERCENTAGES .* left_reward
#         iter_rules_min = deepcopy(rules_min)
#         iter_symbol_min = deepcopy(symbol_min)

#         iter_reward_over_time::Vector{Tuple{Float64, Float64}} = Vector{Tuple{Float64, Float64}}()
#         iter_fragments_used = Vector{Float64}()
#         iter_fragments_mined = Vector{Float64}()

#         iterator = FrAngelRandomIterator(iter_grammar, :Program, iter_rules_min, iter_symbol_min, max_depth=CONFIG.generation.max_size)

#         solution = nothing
#         iterations = 0
#         try
#             (solution, iterations) = frangel(spec, CONFIG, angelic_conditions, iterator, iter_rules_min, iter_symbol_min, reward_over_time, start_reward, start_time, iter_reward_over_time, iter_fragments_used, iter_fragments_mined, [:InnerStatement, :Direction])   
            
#             iter_final_program = isnothing(solution) ? "nothing" : string(rulenode2expr(solution, iter_grammar))
#             push!(iterations_results, IterationResult(deepcopy(initial_position), iter_reward_over_time, iter_fragments_used, iter_fragments_mined, iterations, time() - iter_start_time, iter_final_program, grammar_to_list(iter_grammar), reward_checkpoints))
#             if !isnothing(solution)
#                 state = execute_on_input(grammar, solution, Dict{Symbol, Any}(:start_pos => initial_position)) 
#                 initial_position = state.current_position
    
#                 left_reward -= state.total_reward
#                 start_reward += state.total_reward
#             end
#             push!(iteration_switch_times, time() - start_time)
#         catch ex
#             if isa(ex, PyCall.PyError) && environment.env.done
#                 iter_final_program = isnothing(solution) ? "nothing" : string(rulenode2expr(solution, grammar))
#                 push!(iterations_results, IterationResult(deepcopy(initial_position), iter_reward_over_time, iter_fragments_used, iter_fragments_mined, iterations, time() - iter_start_time, iter_final_program, grammar_to_list(iter_grammar), reward_checkpoints))

#                 return RunResult(true, time() - start_time, reward_over_time, iteration_switch_times, iterations_results)
#             elseif isa(ex, InterruptException)
#                 println("Stopping...")
#                 throw(ex)
#             else
#                 iter_final_program = "nothing"
#                 push!(iterations_results, IterationResult(deepcopy(initial_position), iter_reward_over_time, iter_fragments_used, iter_fragments_mined, iterations, time() - iter_start_time, iter_final_program, grammar_to_list(iter_grammar), reward_checkpoints))

#                 println("Error:", ex)
#                 return RunResult(false, time() - start_time, reward_over_time, iteration_switch_times, iterations_results)
#             end
#         end       
#     end

#     return RunResult(false, time() - start_time, reward_over_time, iteration_switch_times, iterations_results)
# end

function run_once5(world_seed, random_generator_seed)
    push!(environment.settings, :seed => world_seed)
    reset_env(environment)

    if (environment.env.done)
        println("Environment done")
        reset_env(environment)
        println("Reset again")
    end

    @assert !environment.env.done

    Random.seed!(random_generator_seed)

    start_time = time()
    reward_over_time::Vector{Tuple{Float64, Float64}} = Vector{Tuple{Float64, Float64}}()
    iteration_switch_times::Vector{Float64} = Vector{Float64}()
    iterations_results::Vector{IterationResult} = Vector{IterationResult}()
    initial_position = environment.start_pos

    left_reward = MAX_REWARD
    start_reward = 0.0

    grammar_config = get_minecraft_grammar_config()
    grammar, angelic_conditions = grammar_config.minecraft_grammar, grammar_config.angelic_conditions

    rules_min = rules_minsize(grammar)
    symbol_min = symbols_minsize(grammar, rules_min)

    while time() - start_time < MAX_ALLOWED_TIME_PER_RUN 
        iter_start_time = time()
        iter_grammar = deepcopy(grammar)
        spec = create_spec(left_reward, SPEC_PERCENTAGES, false, initial_position)
        reward_checkpoints = SPEC_PERCENTAGES .* left_reward
        iter_rules_min = deepcopy(rules_min)
        iter_symbol_min = deepcopy(symbol_min)

        iter_reward_over_time::Vector{Tuple{Float64, Float64}} = Vector{Tuple{Float64, Float64}}()
        iter_fragments_used = Vector{Float64}()
        iter_fragments_mined = Vector{Float64}()

        iterator = ExperimentalRandomIterator(iter_grammar, :Program, iter_rules_min, iter_symbol_min, length(grammar.rules), max_depth=CONFIG.generation.max_size)

        solution = nothing
        iterations = 0
        try
            (solution, iterations) = frangel(spec, CONFIG, angelic_conditions, iterator, iter_rules_min, iter_symbol_min, reward_over_time, start_reward, start_time, iter_reward_over_time, iter_fragments_used, iter_fragments_mined)   
            
            iter_final_program = isnothing(solution) ? "nothing" : string(rulenode2expr(solution, iter_grammar))
            push!(iterations_results, IterationResult(deepcopy(initial_position), iter_reward_over_time, iter_fragments_used, iter_fragments_mined, iterations, time() - iter_start_time, iter_final_program, grammar_to_list(iter_grammar), reward_checkpoints))
            if !isnothing(solution)
                state = execute_on_input(grammar, solution, Dict{Symbol, Any}(:start_pos => initial_position)) 
                initial_position = state.current_position
    
                left_reward -= state.total_reward
                start_reward += state.total_reward
            end
            push!(iteration_switch_times, time() - start_time)
        catch ex
            if isa(ex, PyCall.PyError) && environment.env.done
                iter_final_program = isnothing(solution) ? "nothing" : string(rulenode2expr(solution, grammar))
                push!(iterations_results, IterationResult(deepcopy(initial_position), iter_reward_over_time, iter_fragments_used, iter_fragments_mined, iterations, time() - iter_start_time, iter_final_program, grammar_to_list(iter_grammar), reward_checkpoints))

                return RunResult(true, time() - start_time, reward_over_time, iteration_switch_times, iterations_results)
            elseif isa(ex, InterruptException)
                println("Stopping...")
                throw(ex)
            else
                iter_final_program = "nothing"
                push!(iterations_results, IterationResult(deepcopy(initial_position), iter_reward_over_time, iter_fragments_used, iter_fragments_mined, iterations, time() - iter_start_time, iter_final_program, grammar_to_list(iter_grammar), reward_checkpoints))
                println("Error")
                showerror(stdout, ex, catch_backtrace())
                return RunResult(false, time() - start_time, reward_over_time, iteration_switch_times, iterations_results)
            end
        end       
    end

    return RunResult(false, time() - start_time, reward_over_time, iteration_switch_times, iterations_results)
end

# Run the experiment
run_experiment_base()
# SPEC_PERCENTAGES = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
# run_experiment_1()
SPEC_PERCENTAGES = [0.4, 0.5, 0.6, 0.7, 0.8]
run_experiment_2()
SPEC_PERCENTAGES = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]

# run_experiment_4()

# run_experiment_5()

# CONFIG = FrAngelConfig(
#     max_time = MAX_ALLOWED_TIME_PER_ITERATION,
#     compare_programs_by_length = true,
#     generation = FrAngelConfigGeneration(
#         max_size = 40,
#         use_fragments_chance = 0.4,
#         use_angelic_conditions_chance = 0.2,
#     ),
#     angelic = FrAngelConfigAngelic(
#         boolean_expr_max_size = 6,
#         max_execute_attempts = 4,
#     )
# )

# run_experiment_3()