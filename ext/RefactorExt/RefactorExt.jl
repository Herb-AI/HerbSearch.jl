module RefactorExt

using HerbCore, HerbGrammar, HerbSearch, Clingo_jll

include("parsing_JSON.jl")
include("compressions_postprocessing.jl")

function refactor_grammar(
    programs::AbstractVector{RuleNode}, 
    grammar::AbstractGrammar, 
    k::Int = 1,
    max_compression_nodes::Int = 10, 
    time_limit_sec::Int = 60)

    # Parse programs into model
    model = parse_programs(programs)

    # Add constants to program
    amount_of_rules = length(grammar.rules)

    max_children = get_max_children(grammar)

    model *= "\n"
    model *= "\n#const k = $k.\n"
    model *= "\n#const amount_of_rules = $amount_of_rules.\n"
    model *= "\n#const max_children = $max_children.\n"
    model *= "\n#const max_compression_nodes = $max_compression_nodes.\n"


    println(model)

    # Run model
    dir_path = dirname(@__FILE__)
    model_location = joinpath(dir_path, "optimization_attempts.lp")
    command = `$(clingo()) $(model_location) - --outf=2 --time-limit=$time_limit_sec`
    output = IOBuffer()
    run(pipeline(ignorestatus(command), stdin=IOBuffer(model), stdout=output))
    data = String(take!(output))

    # println(data)
    
    # Convert result into grammar rule
    optimal, best_cost, best_values = read_last_witness_from_json(data)

    if isnothing(best_values)
        return grammar
    end

    println(best_values)

    node_assignments::Vector{String} = best_values
    (comp_trees, node2rule) = parse_compressed_subtrees(node_assignments)
    
    best_compressions = construct_subtrees(grammar, comp_trees, node2rule)

    new_grammar = deepcopy(grammar)
    for new_rule in best_compressions
        comp_rule = merge_nonbranching_elements(new_rule, grammar)
        # lift_holes(comp_rule, grammar)
        try
            add_rule!(new_grammar, comp_rule)
        catch
            
        end
    end

    println("Cost is $(best_cost)\tIs optimal: $optimal")

    return new_grammar, best_compressions
end

function get_max_children(gramamr::AbstractGrammar)
    res = -1
    for i in eachindex(gramamr.rules)
        res = max(res, nchildren(gramamr, i)) 
    end
    return res
end

end