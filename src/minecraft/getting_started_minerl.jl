include("minerl.jl")
include("logo_print.jl")

using HerbGrammar, HerbSpecification, HerbSearch, HerbInterpret
using Logging
disable_logging(LogLevel(1))

HerbSearch.test_output_equality(exec_output::Any, out::Any) = test_tuple(exec_output, out)

function test_tuple(a, b)
    if b[2]
        return a[2]
    else
        return b[1] < a[1]
    end
end

SEED = 958129
if !(@isdefined environment)
    println("Initiliazing environment")
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; seed=SEED, inf_health=true, inf_food=true, disable_mobs=true)
    println("Environment initialized")
end

show = true

function mc_init()
    soft_reset_env(environment)
    if show
        environment.env.render()
    end 
    action = environment.env.action_space.noop()
    obs, reward, done, _ = environment.env.step(action)
    (reward, done, obs["xpos"][1], obs["ypos"][1], obs["zpos"][1])
end

Main.mc_init = mc_init

function mc_move(state, directions, sprint, jump, times)
    if state[2]
        return state
    end

    action = environment.env.action_space.noop()
    for direction in directions
       action[direction] = 1
    end
    action["sprint"] = sprint
    action["jump"] = jump

    for i in 1:(times-1)
        obs, reward, done, _ = environment.env.step(action)
        
        state = (state[1] + reward, done, obs["xpos"][1], obs["ypos"][1], obs["zpos"][1])

        if (show) 
            environment.env.render()
        end

        if state[2]
            return state
        end
    end

    obs, reward, done, _ = environment.env.step(action)
    state = (state[1] + reward, done, obs["xpos"][1], obs["ypos"][1], obs["zpos"][1])

    if (show) 
        environment.env.render()
    end

    state
end

Main.mc_move = mc_move

function mc_end(state)
    println(state)
    # (0, false)
    # (total_reward, is_done)
end

Main.mc_end = mc_end

minecraft_grammar = @csgrammar begin
    Program = (
        state = Init;
        Statement;
        End;
        state)
    Init = mc_init()
    End = mc_end(state)
    Num = (Num + Num) | 1 | (getfield(state, 1)) | (getfield(state, 3)) | (getfield(state, 4)) | (getfield(state, 5)) | 0
    Direction = (["forward"]) | (["back"]) | (["left"]) | (["right"]) | (["forward", "left"]) | (["forward", "right"]) | (["back", "left"]) | (["back", "right"])
    Sprint = 1 | 0
    Jump = 1 | 0
    Times = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8
    Action = (mc_move(state, Direction, Sprint, Jump, Times))
    Statement = (state = Action)
    Statement = (Statement ; Statement)
    Statement = (
        while Bool 
            state = Action 
        end)
    Bool = (Num < Num) | (getfield(state, 2)) | !Bool
    End = mc_end(state)
end

function generateSpec(max_reward)
    spec = Vector{IOExample}()
    for i in 1:20
        state = ((i * max_reward) / 20, false)
        spec = push!(spec, IOExample(Dict{Symbol, Any}(), state))
    end

    push!(spec, IOExample(Dict{Symbol, Any}(), (max_reward, true)))
    spec
end

spec = generateSpec(64)
println(spec)

angelic_conditions = Dict{UInt16, UInt8}()
angelic_conditions[31] = 1
config = FrAngelConfig(max_time=90, generation=FrAngelConfigGeneration(use_fragments_chance=0.5, use_angelic_conditions_chance=0.4, max_size=60))

rules_min = rules_minsize(minecraft_grammar)
symbol_min = symbols_minsize(minecraft_grammar, rules_min)
@time begin
    iterator = FrAngelRandomIterator(minecraft_grammar, :Program, rules_min, symbol_min, max_depth=config.generation.max_size)
    solution = frangel(spec, config, angelic_conditions, iterator, rules_min, symbol_min)
end
program = rulenode2expr(solution, minecraft_grammar)
println(execute_on_input(minecraft_grammar, solution, Dict{Symbol, Any}()))
println(program)