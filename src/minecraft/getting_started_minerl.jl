include("minerl.jl")
include("logo_print.jl")

using HerbGrammar, HerbSpecification, HerbSearch, HerbInterpret
using Logging
disable_logging(LogLevel(1))

# Set up FrAngel to use the test_tuple function for output equality
HerbSearch.test_output_equality(exec_output::Any, out::Any) = test_reward_output_tuple(exec_output, out)

# Set up the Minecraft environment
SEED = 958129
if !(@isdefined environment)
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; seed=SEED, inf_health=true, inf_food=true, disable_mobs=true)
    println("Environment initialized")
end

RENDER = true

minecraft_grammar = @csgrammar begin
    Program = (
        state = Init;
        Statement;
        End)
    Init = mc_init(start_pos)
    InnerStatement = (mc_move!(state, Direction, Times, Sprint, Jump, Sneak))
    InnerStatement = (InnerStatement ; InnerStatement)
    InnerStatement = (
        if Bool 
            Statement
        end)
    Statement = InnerStatement
    Statement = (Statement ; Statement)
    Statement = (
        while true
            InnerStatement;
            Bool || break
        end)
    End = mc_end(state)
    Direction = (["forward"]) | (["back"]) | (["left"]) | (["right"]) | (["forward", "left"]) | (["forward", "right"]) | (["back", "left"]) | (["back", "right"])
    Sprint = 0 | 1
    Jump =  0 | 1
    Sneak = 0
    Times = 1 | 2 | 3 | 4
    Bool = is_done(state)
    Bool = !Bool
    End = mc_end(state)
    Bool = mc_was_good_move(state)
    Bool = mc_has_moved(state)
end

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

RANDOM_SEED = 1235

using Random
Random.seed!(RANDOM_SEED)

max_reward = 74.0

initial_start_pos = environment.start_pos 

start = time()
reward_over_time = Vector{Tuple{Float64,Float64}}()
starting_position = initial_start_pos
start_reward = 0.0

while true
    global max_reward = max_reward
    global starting_position = starting_position
    global start_reward = start_reward

    spec = create_spec(max_reward, [0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6], false, starting_position)
    angelic_conditions = Dict{UInt16, UInt8}(5 => 1, 8 => 2)
    config = FrAngelConfig(max_time=20, generation=FrAngelConfigGeneration(use_fragments_chance=0.3, use_angelic_conditions_chance=0, max_size=40))

    rules_min = rules_minsize(minecraft_grammar)
    symbol_min = symbols_minsize(minecraft_grammar, rules_min)
    @time begin
        iterator = FrAngelRandomIterator(deepcopy(minecraft_grammar), :Program, rules_min, symbol_min, max_depth=config.generation.max_size)
        try
            solution = frangel(spec, config, angelic_conditions, iterator, rules_min, symbol_min, reward_over_time, start, start_reward)    
            
            state = execute_on_input(minecraft_grammar, solution, Dict{Symbol, Any}(:start_pos => starting_position)) 

            starting_position = state.current_position
    
            max_reward -= state.total_reward
            start_reward += state.total_reward
        catch e
            println(e)
            println("done?")
            println(reward_over_time)
            reset_env(environment)
            break
        end       
    end

    # # try
    #     state = execute_on_input(minecraft_grammar, solution, Dict{Symbol, Any}(:start_pos => starting_position)) 

    #     starting_position = state.current_position

    #     max_reward -= state.total_reward
    # catch
    #     println("done?")
    #     println(reward_over_time)
    #     reset_env(environment)
    #     break
    # end
    
    println(max_reward)
end