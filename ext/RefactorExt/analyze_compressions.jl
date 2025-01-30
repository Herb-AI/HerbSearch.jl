"""
    generate_stats(global_dict::Dict, compressed_rulenode::Vector{String})

Analyzes 1 AST to see how many times each compression was used.

# Arguments
- `d::Dict`: the global dictionary (key: node_id, value: namedTuple(compressiond_id, parent_id, child_nr, type, [children]))
- `compressed_rulenode::Vector{String}`: a list of assign-statements ["assign(A, X)", assign(B, Y), ...]

# Returns 
- `c_info::Dict{Int64, NamedTuple{(:size, :occurrences), <:Tuple{Int64,Int64}}}`: a dict matching an ASTs `compression_id` to the number of occurrences 
"""
function generate_stats(global_dict::Dict, compressed_rulenode::Vector{String})
    c_info = Dict{Int64, NamedTuple{(:size, :occurrences), <:Tuple{Int64,Int64}}}()

    for assignment in compressed_rulenode

        # parse the compression node id
        node_id = nothing

        m = match(r"\((\d+),", assignment)

        @assert m !== nothing
        @assert length(m.captures) == 1
        node_id = parse(Int64, m.captures[1])

        # find all the compressions of that node
        compr_id = global_dict[node_id].comp_id

        # increment the counter if the compression of compression_id has been used already
        if haskey(c_info, compr_id)
            c_info[compr_id] = (size = c_info[compr_id].size, occurrences = c_info[compr_id].occurrences + 1)

        # initialize the counter for the first usage of the compression
        else
            c_info[compr_id] = (size = get_compression_size(global_dict, compr_id), occurrences = 1)
        end
    end

    for (compr_id, value) in c_info
        # the sum of occurrences of all nodes of a compression must be exactly divisible by the compression's size
        @assert (mod(value.occurrences, value.size) == 0) || (value.size == 0)
        c_info[compr_id] = (size = value.size, occurrences = trunc(Int, value.occurrences / value.size))
    end

    return c_info
end

"""
    get_compression_size(global_dict::Dict, compression_id::Int)

Returns the size of a compression with the id `compression_id`.
# Arguments
- `global_dict::Dict`: the global dictionary (key: node_id, value: namedTuple(compressiond_id, parent_id, child_nr, type, [children]))
- `compression_id::Int`: the compression ID used
"""
function get_compression_size(global_dict::Dict, compression_id::Int)
    return_set = Set()
    for (node_id, value_tuple) in global_dict
        if value_tuple.comp_id == compression_id
            push!(return_set, node_id)
        end
    end
    return length(return_set)
end

###################### COMBINE COMPRESSION STATISTICS #############################
"""
    Combines the statistics of multiple rulenodes and returns the a dictionary with summarized results.

# Arguments
- `stats::Vector{Dict{RuleNode, NamedTuple{(:size,:occurrences), <:Tuple{Int64,Int64}}}}`: a list of dictionaries (key: RuleNode, value: NamedTuple(size, occurrences))
"""
function zip_stats(stats::Vector{Dict{RuleNode, NamedTuple{(:size,:occurrences), <:Tuple{Int64,Int64}}}})::Dict{RuleNode, NamedTuple{(:size,:occurrences)}}
    return_dict = Dict{RuleNode, NamedTuple{(:size,:occurrences), <:Tuple{Int64,Int64}}}()
    for stat in stats
        for (key, value) in stat
            if !haskey(return_dict, key)
                return_dict[key] = (size = value.size, occurrences = 0)
            end
            return_dict[key] = (size = return_dict[key].size, occurrences = return_dict[key].occurrences + value.occurrences)
        end
    end
    
    return return_dict
end

"""

Selection strategy for compression.

Select either:
- based on the # of occurrences alone, or
- based on the # of occurrences * their size
"""
@enum SelectionStrategy begin
    occurrences
    occurrences_and_size
end

"""
    select_compressions(selection_strategy::SelectionStrategy, compression_dict::Dict, f_best::Real)::Vector{RuleNode}

Selects the best compressions according to the selected heuristic.

Compression type may be chosen by assigning `selection_strategy`. Returns a sorted and filtered list of compression IDs.

# Arguments
- `compression_type::CompressionType`: the heuristic to use (1: occurrences, 2: occurrences * size)
- `compression_dict::Dict{RuleNode, NamedTuple{(:size,:occurrences), <:Tuple{Int64,Int64}}}`: a dictionary (key: compression (RuleNode), value: tuple(size, # occurrences))
- `f_best::Real`: a float in range [0,1], that specifies what proportion of the compressions will get selected
"""
function select_compressions(selection_strategy::SelectionStrategy, compression_dict::Dict, f_best::Real)::Vector{RuleNode}
    # type 1: occurrences 
    if selection_strategy == occurrences
        @debug "Sorting by #occurrences..."
        compression_dict = compress_by_occurrences(compression_dict)
    # type 2: occurrences * size
    elseif selection_strategy == occurrences_and_size
        @debug "sorting by #occurrences * tree_size..."
        compression_dict = compress_by_occurrences_and_size(compression_dict)
    end

    # filter out compressions of size 1
    filter!(x -> x[2].size != 1, compression_dict)
    
    # filter out compressions with less than 2 occurrences
    filter!(x -> x[2].occurrences >= 2, compression_dict)
    # taking the best n percentage
    index = ceil.(Int, length(compression_dict) * f_best)
    compression_dict = compression_dict[begin:index]

   return map(first, compression_dict)
end

compress_by_occurrences(c::Dict) = sort(collect(c), by=x->x[2].occurrences, rev=true) # decreasing order of value
compress_by_occurrences_and_size(c::Dict) = sort(collect(c), by=x->(x[2].occurrences * x[2].size), rev=true) # decreasing order of value
