module CompressionExt

using DocStringExtensions
using HerbCore
using HerbGrammar
using HerbSearch
using Clingo_jll

include("clingo_io.jl")
include("refactor_holes.jl")

"""
    $(TYPEDSIGNATURES)

# Arguments
- `programs`: programs as ASTs from which the subtrees will be extracted.
- `grammar`: grammar that will be extended with new rules
- `k`: number of subprogtrams that will be extracted. default=1
- `max_compression_tokens`, def=10: maximum number of tokens (or nodes in ATSs) among the extracted subtrees. 
- `time_limit_sec`, def=60: maximum amount of time the clingo model will run for. If optimal solution is not found, then the best solution found so far is returned.
- `ASP_PATH`, def="compression.lp": path to the file wiht the Clingo model.
    It terminates after after finding optimal results or the given time limit, 
    in which case best compression found so far is used. 
    
# Returns
- `rules`: a list of new rules.
"""
function HerbSearch.compress_programs(
    programs::AbstractVector{<:AbstractRuleNode},
    grammar::AbstractGrammar;
    k::Int=1,
    max_compression_nodes::Int=10,
    time_limit_sec::Int=60,
    ASP_PATH::String="compression.lp")

    # Parse programs into a Clingo model
    model = parse_programs(programs)

    # Add constants to the model
    amount_of_rules = length(grammar.rules)

    max_children = _get_max_children(grammar)

    model *= "\n"
    model *= "\n#const k = $k.\n"
    model *= "\n#const amount_of_rules = $amount_of_rules.\n"
    model *= "\n#const max_children = $max_children.\n"
    model *= "\n#const max_compression_nodes = $max_compression_nodes.\n"

    # Run model
    dir_path = dirname(@__FILE__)
    model_location = joinpath(dir_path, ASP_PATH)
    command = `$(clingo()) $(model_location) - --outf=2 --time-limit=$time_limit_sec`
    output = IOBuffer()
    run(pipeline(ignorestatus(command), stdin=IOBuffer(model), stdout=output))

    data = String(take!(output))

    # Convert result into grammar rule
    _, _, best_values = read_last_witness_from_json(data)

    # if no solution was found due to timeout or because theere are no subtree to be extracted, return the old grammar.
    if isnothing(best_values)
        return []
    end

    node_assignments::Vector{String} = best_values
    (comp_trees, node2rule) = parse_compressed_subtrees(node_assignments)

    best_compressions = construct_subtrees(grammar, comp_trees, node2rule)
    new_rules = merge_nonbranching_elements.(best_compressions, (grammar,))
    return new_rules
end

function HerbSearch.compress_to_expressions(
    programs::AbstractVector{<:AbstractRuleNode},
    grammar::AbstractGrammar; 
    kwargs...)::Vector{Expr}
    new_rules = HerbSearch.compress_programs(programs, grammar; kwargs...)
    return vcat([create_new_exprs(nr, grammar, i) for (i, nr) in enumerate(new_rules)]...)
end

"""
    $(TYPEDSIGNATURES)

Returns the maximum amount of children among the rules of the grammar.
"""
function _get_max_children(grammar::AbstractGrammar)::Int
    res = -1
    for i in eachindex(grammar.rules)
        res = max(res, nchildren(grammar, i))
    end
    return res
end

export
    compress_programs,
    create_new_exprs, 
    split_hole
end
