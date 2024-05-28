include("minerl.jl")
include("logo_print.jl")

using HerbGrammar, HerbSpecification, HerbSearch, HerbInterpret
using Logging
disable_logging(LogLevel(1))

function generateLinearSpec(steps::Int)::Vector{IOExample}
    input = Dict{Symbol, Any}()
    spec = Vector{IOExample}()
    for i in 1:steps 
        push!(spec, IOExample(input, (i / steps) / 4))
    end
    return spec
end

HerbSearch.test_output_equality(exec_output::Any, out::Any) = test_output_equal_or_greater(exec_output, out)

SEED = 958129
if !(@isdefined environment)
    println("Initiliazing environment")
    environment = create_env("MineRLNavigateDenseProgSynth-v0"; seed=SEED, inf_health=true, inf_food=true, disable_mobs=true)
    println("Environment initialized")
end

function start_program()::Nothing
    # println("------------------------------------------")
    # print_logo()
end

function reset()::Nothing
    # println("Environment reset")
    soft_reset_env(environment)
end

# print_logo()

function get_xyz_from_obs(obs)::Tuple{Float64,Float64,Float64}
    return obs["xpos"][1], obs["ypos"][1], obs["zpos"][1]
end

function position()
    action = environment.env.action_space.noop()
    obs, reward, done, _ = environment.env.step(action)
    global x = obs["xpos"][1] 
    global y = obs["ypos"][1]
    global z = obs["zpos"][1]
    global reward = reward
end

function print_position()
    # println("x: $(x), y: $(y), z: $(z)")
    # println("reward: $(reward)")
end

function has_moved()
    return !@isdefined(old_x) || x != old_x || y != old_y || z != old_z
end
   
sprint_jump_forward() = sprint_jump("forward")
sprint_jump_backward() = sprint_jump("back")
sprint_jump_left() = sprint_jump("left")
sprint_jump_right() = sprint_jump("right")

function sprint_jump(direction)
    global old_x = x
    global old_y = y
    global old_z = z

    action = environment.env.action_space.noop()
    action[direction] = 1
    action["sprint"] = 1
    action["jump"] = 1
    obs, reward, done, _ = environment.env.step(action)
    global x = obs["xpos"][1] 
    global y = obs["ypos"][1]
    global z = obs["zpos"][1]
    global reward = reward
end

function move_forward()
    global old_x = x
    global old_y = y
    global old_z = z

    action = environment.env.action_space.noop()
    action["forward"] = 1
    obs, reward, done, _ = environment.env.step(action)
    global x = obs["xpos"][1] 
    global y = obs["ypos"][1]
    global z = obs["zpos"][1]
    global reward = reward
end

function move_backward()
    global old_x = x
    global old_y = y
    global old_z = z

    action = environment.env.action_space.noop()
    action["back"] = 1
    obs, reward, done, _ = environment.env.step(action)
    global x = obs["xpos"][1] 
    global y = obs["ypos"][1]
    global z = obs["zpos"][1]
    global reward = reward
end

function move_left()
    global old_x = x
    global old_y = y
    global old_z = z

    action = environment.env.action_space.noop()
    action["left"] = 1
    obs, reward, done, _ = environment.env.step(action)
    global x = obs["xpos"][1] 
    global y = obs["ypos"][1]
    global z = obs["zpos"][1]
    global reward = reward
end

function move_right()
    global old_x = x
    global old_y = y
    global old_z = z

    action = environment.env.action_space.noop()
    action["right"] = 1
    obs, reward, done, _ = environment.env.step(action)
    global x = obs["xpos"][1] 
    global y = obs["ypos"][1]
    global z = obs["zpos"][1]
    global reward = reward
end

function end_program()
    # println("------------------------------------------")
    # println()
    reward
end

grammar = @cfgrammar begin
    Program = (START ; RESET ; POSITION ; PRINT ; Statement ; PRINT ; END)
    START = start_program()
    RESET = reset()
    POSITION = position()
    PRINT = print_position()
    END = end_program()
    Statement = (while Bool Action end)
    Statement = (Statement ; Statement)
    Statement = Action
    Action = move_forward()
    Action = move_backward()
    Action = move_left()
    Action = move_right()
    Action = sprint_jump_forward()
    Action = sprint_jump_backward()
    Action = sprint_jump_left()
    Action = sprint_jump_right()
    Bool = has_moved()
end

spec = generateLinearSpec(20)
problem = Problem(spec)

angelic_conditions = Dict{UInt16, UInt8}()
angelic_conditions[7] = 1
config = FrAngelConfig(max_time=120, generation=FrAngelConfigGeneration(use_fragments_chance=0.5, use_angelic_conditions_chance=0))

rules_min = rules_minsize(grammar)
symbol_min = symbols_minsize(grammar, rules_min)
@time begin
    iterator = FrAngelRandomIterator(grammar, :Program, rules_min, symbol_min, max_depth=config.generation.max_size)
    solution = frangel(spec, config, angelic_conditions, iterator, rules_min, symbol_min)
end
program = rulenode2expr(solution, grammar)
println(execute_on_input(grammar, solution, Dict{Symbol, Any}()))
println(program)

# println(grammar)

# program = RuleNode(1, [RuleNode(2), RuleNode(3), RuleNode(4), RuleNode(5), RuleNode(7, [RuleNode(9), RuleNode(8)]), RuleNode(5), RuleNode(6)])

# println(rulenode2expr(program, grammar))

# a = execute_on_input(grammar, program, Dict{Symbol, Any}())
# println(a)
# # minerl_grammar = @pcsgrammar begin
# #     1:SEQ = [ACT]
# #     8:DIR = 0b0001 | 0b0010 | 0b0100 | 0b1000 | 0b0101 | 0b1001 | 0b0110 | 0b1010 # forward | back | left | right | forward-left | forward-right | back-left | back-right
# #     1:ACT = (TIMES, Dict("move" => DIR, "sprint" => 1, "jump" => 1))
# #     6:TIMES = 5 | 10 | 25 | 50 | 75 | 100
# # end

# # HerbSearch.evaluate_trace(prog::RuleNode, grammar::ContextSensitiveGrammar; show_moves=true) = evaluate_trace_minerl(prog, grammar, environment, show_moves)

# # print_logo()
# # iter = HerbSearch.GuidedSearchTraceIterator(minerl_grammar, :SEQ)
# # program = @time probe(Vector{Trace}(), iter, max_time=3000000, cycle_length=6)
 