"""
    generate_stats(d, compressed_AST)

Compression Analysis. Analyzes 1 AST to see how many times each compression was used.
# Arguments
- `d::Dict`: the global dictionary (key: node_id, value: namedTuple(compressiond_id, parent_id, child_nr, type, [children]))
- `compressed_AST::Vector{String}`: a list of assign-statements ["assign(A, X)", assign(B, Y), ...]
# Result 
- `c_info::Dict{Int64, NamedTuple{(:size, :occurences), <:Tuple{Int64,Int64}}}`: an dict(key: compression_id, value: Tuple(size, # occurences))) 
"""
function generate_stats(d, compressed_AST)
    # (key: subtree ID, value: NamedTuple([subtree node IDs], # occurences))
    # c_info = Dict{Int64, NamedTuple{:size, :occurences}{Int64, Int64}}()
    c_info = Dict{Int64, NamedTuple{(:size, :occurences), <:Tuple{Int64,Int64}}}()


    for assign in compressed_AST

        # parse the compression node id
        node_id = nothing

        m = match(r"\((\d+),", assign)

        @assert m !== nothing
        @assert length(m.captures) == 1
        node_id = parse(Int64, m.captures[1])

        # find all the compressions of that node
        C = d[node_id].comp_id

        # increment the counter if the compression C has been used already
        if haskey(c_info, C)
            c_info[C] = (size = c_info[C].size, occurences = c_info[C].occurences + 1)

        # initialize the counter for the first usage of the compression
        else
            c_info[C] = (size = getCompressionSize(d, C), occurences = 1)
        end
    end

    for (C, v) in c_info
        # the sum of occurences of all nodes of a compression must be exactly divisible by the compression's size
        @assert (mod(v.occurences, v.size) == 0) || (v.size == 0)
        c_info[C] = (size = v.size, occurences = trunc(Int, v.occurences / v.size))
    end

    return c_info
end

"""
    compare(rn₁, rn₂)

Compares two RuleNodes. Returns true if they are equal, false otherwise.
# Arguments
- `rn₁::RuleNode`: a RuleNode
- `rn₂::RuleNode`: a RuleNode
# Result
- `Bool`: true if the RuleNodes are equal, false otherwise
"""
function compare(rn₁, rn₂)::Bool  
    if typeof(rn₁) != typeof(rn₂) return false end
    if (rn₁ isa Hole) && (rn₂ isa Hole) return true end
    if !(rn₁ isa RuleNode) || !(rn₂ isa RuleNode) return false end

    if rn₁.ind == rn₂.ind
        for (c₁, c₂) ∈ zip(rn₁.children, rn₂.children)
            comparison = compare(c₁, c₂)
            # comparison ≡ softfail && return softfail
            if !comparison return false end
        end
        return true
    end
    return false
end

"""
    getCompressionSize(d, C)

Returns the size of a compression C.
# Arguments
- `d::Dict`: the global dictionary (key: node_id, value: namedTuple(compressiond_id, parent_id, child_nr, type, [children]))
- `C::Int64`: the compression ID
"""
function getCompressionSize(d, C)
    s = Set()
    for (k,v) in d
        if v.comp_id == C
            push!(s, k)
        end
    end
    return length(s)
end

###################### COMBINE COMPRESSION STATISTICS #############################

Base.isequal(k1::RuleNode, k2::RuleNode) = compare(k1, k2) #k1.field1 == k2.field1 && k1.field2 == k2.field2

function zip_stats(stats::Vector{Dict{RuleNode, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}})
    """
    Combines the statistics of multiple ASTs into one dictionary.
    # Arguments
    - `stats::Vector{Dict{RuleNode, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}}`: a list of dictionaries (key: RuleNode, value: NamedTuple(size, occurences))
    # Result
    - `d::Dict{RuleNode, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}`: a dictionary (key: RuleNode, value: NamedTuple(size, occurences))
    """
    d = Dict{RuleNode, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}()
    for s in stats
        for (k,v) in s
            if !haskey(d, k)
                d[k] = (size = v.size, occurences = 0)
            end
            @assert d[k].size == v.size
            d[k] = (size = d[k].size, occurences = d[k].occurences + v.occurences)
        end
    end
    
    return d

end


function select_compressions(case, c, f_best, verbosity=0)
    """
    Selects the best compressions according to some heuristic.
    # Arguments
    - `case::Int64`: the heuristic to use (1: occurences, 2: occurences * size)
    - `c::Dict{RuleNode, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}`: a dictionary (key: compression (RuleNode), value: tuple(size, # occurences))
    - `f_best::Float64`: a float in range [0,1], that specifies what proportion of the compressions will get selected
    # Result
    - `c::Vector{RuleNode}`: a sorted and filtered list of compression IDs
    """
    # case 1: occurences
    if case == 1
        verbosity > 0 && println("sorting by #occurences...")
        c = sort(collect(c), by=x->x[2].occurences, rev=true) # decreasing order of value
    # case 2: occurences * size
    elseif  case ==2
        verbosity > 0 && println("sorting by #occurences * tree_size...")
        c = sort(collect(c), by=x->(x[2].occurences * x[2].size), rev=true) # decreasing order of value
    end

    # filter out compressions of size 1
    filter!(x -> x[2].size != 1, c)
    
    # filter out compressions with less than 2 occurences
    filter!(x -> x[2].occurences >= 2, c)
    # taking the best n percentage
    index = ceil.(Int, length(c) * f_best)
    c = c[begin:index]


   return map(first, c)
end