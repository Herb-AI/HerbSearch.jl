using HerbCore, HerbGrammar, HerbSearch, HerbBenchmarks, HerbConstraints

include("string_functions.jl")

benchmark = HerbBenchmarks.PBE_SLIA_Track_2019
problem = benchmark.problem_11604909
grammar = benchmark.grammar_11604909
starting_symbol = :ntString

property_grammar = deepcopy(grammar)
merge_grammars!(property_grammar, @cfgrammar begin
    ntBool = ntString == ntString
    ntBool = ntInt == ntInt
    ntBool = ntInt <= ntInt
    ntBool = ntInt < ntInt
    ntBool = and(ntBool, ntBool)
    ntBool = or(ntBool, ntBool)
    ntBool = xor(ntBool, ntBool)
    ntBool = implies(ntBool, ntBool)
    ntString = _arg_out
end)
addconstraint!(property_grammar, Contains(length(property_grammar.rules)))
grammar_tags = benchmark.get_relevant_tags(property_grammar)

properties = Vector{AbstractRuleNode}(collect(BFSIterator(property_grammar, :ntBool, 
    max_depth = 4, 
    max_size = 6,
)))

iterator = PropertyBasedNeighborhoodIterator(grammar, starting_symbol,
    problem,
    (p, x) -> interpret_sygus(p, grammar_tags, x),
    10,
    properties,

    max_extension_depth = 2,
    max_extension_size = 4,

    property_grammar = property_grammar,

    max_number_of_properties = 20,
)

for io in problem.spec
    println("$(io.in) -> $(io.out)")
end


for (i, program) in enumerate(iterator)
    cost = heuristic_cost(iterator, program)
    expr = rulenode2expr(program, grammar)
    
    println()
    @show i
    @show expr
    @show program._val
    @show cost

    if program._val == [io.out for io in problem.spec]
        println("\nSolution found in $i iterations!")
        expr = rulenode2expr(program, grammar)
        @show expr

        break
    end

    if i == 500
        println("Reached max iterations")
        break
    end
end

println("\nWith $(length(iterator.selected_properties)) properties:")
for property in iterator.selected_properties
    prop = rulenode2expr(property, property_grammar)
    println(" - $prop")
end

#=

Dict{Symbol, Any}(:_arg_1 => "AIX 5.1") -> 5.1
Dict{Symbol, Any}(:_arg_1 => "VMware ESX Server 3.5.0 build-110268") -> 3.5
Dict{Symbol, Any}(:_arg_1 => "Linux Linux 2.6 Linux") -> 2.6
Dict{Symbol, Any}(:_arg_1 => "Red Hat Enterprise AS 4 <2.6-78.0.13.ELl_arg_esmp>") -> 2.6
Dict{Symbol, Any}(:_arg_1 => "Microsoft <R> Windows <R> 2000 Advanced Server 1.0") -> 1.0
Dict{Symbol, Any}(:_arg_1 => "Microsoft Windows XP Win2008R2 6.1.7601") -> 6.1


=#