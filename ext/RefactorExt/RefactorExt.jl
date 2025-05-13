module RefactorExt

using HerbCore, HerbGrammar, HerbSearch, Clingo_jll

include("parsing_JSON.jl")
include("compressions_postprocessing.jl")


function HerbSearch.refactor_grammar(programs::AbstractVector{RuleNode}, grammar::AbstractGrammar, k::Int)
    # Parse programs into model
    model = parse_programs(programs)
    model *= "#const k = $k."

    # Run model
    dir_path = dirname(@__FILE__)     
    #model_location = joinpath(dir_path, "model.lp")
    model_location = joinpath(dir_path, "model_count.lp")
    command = `$(clingo()) $(model_location) - --outf=2`
    output = IOBuffer()
    run(pipeline(ignorestatus(command), stdin=IOBuffer(model), stdout=output))
    data = String(take!(output))

    println(data)
    
    # Convert result into grammar rule
    best_values = read_last_witness_from_json(data)
    node_assignments::Vector{String} = best_values
    (comp_trees, node2rule) = parse_compressed_subtrees(node_assignments)

    best_compressions = construct_subtrees(grammar, comp_trees, node2rule)

    new_grammar = deepcopy(grammar)
    for new_rule in best_compressions
        add_rule!(new_grammar, new_rule)
    end

    return new_grammar
end

end