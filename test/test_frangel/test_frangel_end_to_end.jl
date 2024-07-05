g = @cfgrammar begin
    Num = |(0:10)
    Num = x | (Num + Num)
    Bool = true | false | (Num == Num) | (Num < Num)
    Num = (
        if Bool
            Num
        else
            Num
        end
    )
end

@testset "basic_example_fragments_only" begin
    spec = [IOExample(Dict(:x => x), 3x) for x ∈ 1:5]
    problem = Problem(spec)
    rules_min = rules_minsize(g)
    symbol_min = symbols_minsize(g, rules_min)

    config = FrAngelConfig(verbose_level=0, generation=FrAngelConfigGeneration(use_fragments_chance=0.5, use_angelic_conditions_chance=0, max_size=20))
    @time begin
        # @time @profview begin     
        iterator = FrAngelRandomIterator(deepcopy(g), :Num, rules_min, symbol_min, max_depth=config.generation.max_size)
        solution = frangel(spec, config, Dict{UInt16, UInt8}(), iterator, rules_min, symbol_min)
    end
    program = rulenode2expr(solution, g)
    println(program)

    @time begin
        iterator = BFSIterator(g, :Num, max_depth=10)
        solution, flag = synth(problem, iterator)
    end
    program = rulenode2expr(solution, g)
    println(program)
end

# @testset "basic_example_with_angelic" begin
#     spec = [
#         IOExample(Dict(:x => 1), 2)
#         IOExample(Dict(:x => 2), 3)
#         IOExample(Dict(:x => 3), 3)
#         IOExample(Dict(:x => 4), 5)
#         IOExample(Dict(:x => 5), 6)
#         IOExample(Dict(:x => 6), 7)
#     ]
#     problem = Problem(spec)
#     rules_min = rules_minsize(g)
#     symbol_min = symbols_minsize(g, rules_min)
#     config = FrAngelConfig(max_time=20, verbose_level=0,
#         generation=FrAngelConfigGeneration(use_fragments_chance=0.5, use_angelic_conditions_chance=0.75, max_size=20),
#         angelic=FrAngelConfigAngelic(max_allowed_fails=0.5, max_execute_attempts=5))
#     angelic_conditions = Dict{UInt16,UInt8}(18 => 1)

#     @time begin
#     # @time @profview begin
#         iterator = FrAngelRandomIterator(deepcopy(g), :Num, rules_min, symbol_min, max_depth=config.generation.max_size)
#         solution = frangel(spec, config, angelic_conditions, iterator, rules_min, symbol_min)
#     end
#     program = rulenode2expr(solution, g)
#     println(program)

#     @time begin
#         iterator = BFSIterator(g, :Num, max_depth=10)
#         solution, flag = synth(problem, iterator)
#     end
#     program = rulenode2expr(solution, g)
#     println(program)
# end

# @testset "getRange" begin
#     grammar = buildProgrammingProblemGrammar([(:endd, :Num), (:start, :Num)], :List)
#     spec = [
#         IOExample(Dict(:start => 10, :endd => 15), [10, 11, 12, 13, 14]),
#         IOExample(Dict(:start => 10, :endd => 11), [10]),
#         IOExample(Dict(:start => 0, :endd => 1), [0]),
#     ]
#     problem = Problem(spec)
#     angelic_conditions = Dict{UInt16,UInt8}(6 => 1, 7 => 1)

#     config = FrAngelConfig(max_time=10, generation=FrAngelConfigGeneration(use_fragments_chance=0.5, use_angelic_conditions_chance=0.5))

#     rules_min = rules_minsize(grammar)
#     symbol_min = symbols_minsize(grammar, rules_min)
#     @time begin
#         iterator = FrAngelRandomIterator(grammar, :Program, rules_min, symbol_min, max_depth=config.generation.max_size)
#         solution = frangel(spec, config, angelic_conditions, iterator, rules_min, symbol_min)
#     end
#     program = rulenode2expr(solution, grammar)
#     println(program)
# end