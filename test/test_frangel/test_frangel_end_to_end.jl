g = @cfgrammar begin
    Num = |(0:10)
    Num = x | (Num + Num)
    Bool = (Num == Num)
    Num = (if Bool ; Num else Num end)
end

@testset "basic_example" begin
    spec = [IOExample(Dict(:x => x), 2x) for x ∈ 1:5]
    problem = Problem(spec)
    rules_min = rules_minsize(g)
    symbol_min = symbols_minsize(g, rules_min)

    config = FrAngelConfig(verbose_level=0, generation=FrAngelConfigGeneration(use_fragments_chance=0.5, use_angelic_conditions_chance=0, max_size=20))
    @time begin
        # @time @profview begin     
        iterator = FrAngelRandomIterator(deepcopy(g), :Num, rules_min, symbol_min, max_depth=config.generation.max_size)
        solution = frangel(spec, config, AbstractVector{Union{Nothing,Int64}}([nothing for rule in g.rules]), iterator, rules_min, symbol_min)
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

@testset "basic_example_2" begin
    spec = [
        IOExample(Dict(:x => 1), 2)
        IOExample(Dict(:x => 2), 3)
        IOExample(Dict(:x => 3), 3)
        IOExample(Dict(:x => 4), 5)
        IOExample(Dict(:x => 5), 6)
        IOExample(Dict(:x => 6), 7)
    ]
    problem = Problem(spec)
    rules_min = rules_minsize(g)
    symbol_min = symbols_minsize(g, rules_min)

    config = FrAngelConfig(verbose_level=0, generation=FrAngelConfigGeneration(use_fragments_chance=0.5, use_angelic_conditions_chance=0, max_size=20))
    @time begin
        # @time @profview begin     
        iterator = FrAngelRandomIterator(deepcopy(g), :Num, rules_min, symbol_min, max_depth=config.generation.max_size)
        solution = frangel(spec, config, AbstractVector{Union{Nothing,Int64}}([nothing for rule in g.rules]), iterator, rules_min, symbol_min)
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

@testset "getRange" begin
    grammar = buildProgrammingProblemGrammar([(:endd, :Num), (:start, :Num)], :List)
    spec = [
        IOExample(Dict(:start => 10, :endd => 15), [10, 11, 12, 13, 14]),
        IOExample(Dict(:start => 10, :endd => 11), [10]),
        IOExample(Dict(:start => 0, :endd => 1), [0]),
    ]
    problem = Problem(spec)

    angelic_conditions = AbstractVector{Union{Nothing,Int64}}([nothing for rule in grammar.rules])
    angelic_conditions[6] = 1
    angelic_conditions[7] = 1
    config = FrAngelConfig(max_time=40, generation=FrAngelConfigGeneration(use_fragments_chance=Float16(0.5), use_angelic_conditions_chance=0))

    rules_min = rules_minsize(grammar)
    symbol_min = symbols_minsize(grammar, rules_min)
    @time begin
        iterator = FrAngelRandomIterator(grammar, :Program, rules_min, symbol_min, max_depth=config.generation.max_size)
        solution = frangel(spec, config, angelic_conditions, iterator, rules_min, symbol_min)
    end
    program = rulenode2expr(solution, grammar)
    println(program)
end