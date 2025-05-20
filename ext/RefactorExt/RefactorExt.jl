module RefactorExt

using HerbCore, HerbGrammar, HerbSearch, Clingo_jll

include("parsing_JSON.jl")
include("compressions_postprocessing.jl")


function HerbSearch.refactor_grammar(programs::AbstractVector{RuleNode}, grammar::AbstractGrammar, k::Int = 1, max_children::Int = 2, max_compression_nodes::Int = 10, time_limit_sec::Int = 60)
    # Parse programs into model
    model = parse_programs(programs)

    # Add constants to program
    amount_of_rules = length(grammar.rules)

    model *= "\n"
    model *= "\n#const k = $k.\n"
    model *= "\n#const amount_of_rules = $amount_of_rules.\n"
    model *= "\n#const max_children = $max_children.\n"
    model *= "\n#const max_compression_nodes = $max_compression_nodes.\n"


    println(model)

    OLD_MODEL = false
    # Run model
    dir_path = dirname(@__FILE__)     
    if OLD_MODEL
        model_location = joinpath(dir_path, "model.lp")
    else
        model_location = joinpath(dir_path, "optimization_attempts.lp")
    end
    command = `$(clingo()) $(model_location) - --outf=2 --time-limit=$time_limit_sec`
    output = IOBuffer()
    run(pipeline(ignorestatus(command), stdin=IOBuffer(model), stdout=output))
    data = String(take!(output))

    println(data)
    
    # Convert result into grammar rule
    best_values = read_last_witness_from_json(data)

    if isnothing(best_values)
        return grammar
    end

    node_assignments::Vector{String} = best_values
    (comp_trees, node2rule) = parse_compressed_subtrees(node_assignments, OLD_MODEL)
    
    best_compressions = construct_subtrees(grammar, comp_trees, node2rule)

    new_grammar = deepcopy(grammar)
    for new_rule in best_compressions
        println("uncompressed rule:\t$new_rule")
        comp_rule = merge_nonbranching_elements(new_rule, grammar)
        println("compressed rule:\t$comp_rule")
        add_rule!(new_grammar, comp_rule)
    end

    return new_grammar
end

end