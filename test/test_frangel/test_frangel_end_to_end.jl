g = @cfgrammar begin
    Num = |(0:10)
    Num = x | (Num + Num)
    Bool = (Num == Num)
    Num = (if Bool ; Num else Num end)
end

@testset "basic_example" begin
    spec = [IOExample(Dict(:x => x), 2x) for x ∈ 1:5]
    problem = Problem(spec)
    config = FrAngelConfig(verbose_level = 20, generation = FrAngelConfigGeneration(use_fragments_chance = 0.5, use_angelic_conditions_chance = 0, max_size=20))
    angelic_conditions = AbstractVector{Union{Nothing, Int64}}([nothing for rule in g.rules])
    rules_min = rules_minsize(g)
    symbol_min = symbols_minsize(g, rules_min)
    base_g = deepcopy(g)

    @time begin     
    # @time @profview begin     
        iterator = FrAngelRandomIterator(g, :Num, rules_min, symbol_min, max_depth = config.generation.max_size)
        solution = frangel(spec, config, angelic_conditions, iterator, rules_min, symbol_min) 
    end
    program = rulenode2expr(solution, g) # should yield 2*6 +1 
    println(program)

    @time begin 
        iterator = BFSIterator(base_g, :Num, max_depth=10)
        solution, flag = synth(problem, iterator)
    end
    program = rulenode2expr(solution, base_g) # should yield 2*6 +1 
    println(program)
end

function buildProgrammingProblemGrammar(
    input_parameters::AbstractVector{Tuple{Symbol, Symbol}}, 
    return_type::Symbol,
    intermediate_variables_count::Int=0
)::ContextSensitiveGrammar
    base_grammar = @cfgrammar begin
        
        Program = (VariableDefintion ; Statement ; Return) | (Statement ; Return) | Return
        VariableDefintion = ListVariable = List

        Statement = (Statement ; Statement)
        Statement = (
            i = 0;
            while i < Num
                InnerStatement
                i = i + 1
            end)
        Statement = (if Bool Statement end)
        Statement = push!(ListVariable, Num)

        InnerNum = Num | i | (InnerNum + InnerNum)
        InnerStatement = push!(ListVariable, InnerNum)
        
        Num = |(0:9) | (Num + Num) | (Num - Num)
        Num = getindex(ListVariable, Num)

        Bool = true | false

        List = [] | ListVariable

        ListVariable = list
    end

    # add return type constraint
    add_rule!(base_grammar, :(Return = return $return_type))

    # add input parameters constraints
    for input_parameter in input_parameters 
        add_rule!(base_grammar, :($(input_parameter[2]) = $(input_parameter[1])))
    end

    # what about order constrains for while loops?
    # what about order constrains for variables

    base_grammar
end

@testset "getRange" begin
    grammar = buildProgrammingProblemGrammar([(:endd, :Num), (:start, :Num)], :List)

    spec = [
        IOExample(Dict(:start => 10, :endd => 15), [10, 11, 12, 13, 14]),
        IOExample(Dict(:start => 10, :endd => 11), [10]),
        IOExample(Dict(:start => 0, :endd => 1), [0]),
    ]
    problem = Problem(spec)
    b_grammar = deepcopy(grammar)

    angelic_conditions = AbstractVector{Union{Nothing, Int64}}([nothing for rule in grammar.rules])
    angelic_conditions[6] = 1
    angelic_conditions[7] = 1
    config = FrAngelConfig(max_time = 80, generation = FrAngelConfigGeneration(use_fragments_chance = Float16(0.5), use_angelic_conditions_chance = 0))

    rules_min = rules_minsize(grammar)
    symbol_min = symbols_minsize(grammar, rules_min)
    @time begin
        iterator = FrAngelRandomIterator(grammar, :Program, rules_min, symbol_min, max_depth = config.generation.max_size)
        solution = frangel(spec, config, angelic_conditions, iterator, rules_min, symbol_min) 
    end
    program = rulenode2expr(solution, grammar) 
    println(program)

    @time begin 
        iterator = BFSIterator(b_grammar, :Num, max_depth=40)
        solution, flag = synth(problem, iterator)
    end
    program = rulenode2expr(solution, b_grammar) # should yield 2*6 +1 
    println(program)
end