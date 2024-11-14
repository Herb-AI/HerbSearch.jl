function generate_stats(d, compressed_AST)
    """
    Compression Analysis. Analyzes 1 AST to see how many times each compression was used.
    # Arguments
    - `d::Dict`: the global dictionary (key: node_id, value: namedTuple(compressiond_id, parent_id, child_nr, type, [children]))
    - `compressed_AST::Vector{String}`: a list of assign-statements ["assign(A, X)", assign(B, Y), ...]
    # Result 
    - `c_info::Dict{Int64, NamedTuple{(:size, :occurences), <:Tuple{Int64,Int64}}}`: an dict(key: compression_id, value: Tuple(size, # occurences))) 
    """

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

function compare(rn₁, rn₂)::Bool
    """
    Compares two RuleNodes. Returns true if they are equal, false otherwise.
    # Arguments
    - `rn₁::RuleNode`: a RuleNode
    - `rn₂::RuleNode`: a RuleNode
    # Result
    - `Bool`: true if the RuleNodes are equal, false otherwise
    """
    
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

function getCompressionSize(d, C)
    """
    Returns the size of a compression C.
    # Arguments
    - `d::Dict`: the global dictionary (key: node_id, value: namedTuple(compressiond_id, parent_id, child_nr, type, [children]))
    - `C::Int64`: the compression ID
    """
    s = Set()
    for (k,v) in d
        if v.comp_id == C
            push!(s, k)
        end
    end
    return length(s)
end

###################### EXAMPLE USAGE #############################

# Subtree_dict = Dict{Int64, Vector}(1 => [7,8,9], 0 => [2,3,5])
Subtree_dict = Dict{Int64, NamedTuple{(:comp_id, :parent_id, :child_nr, :type, :children), <:Tuple{Int64,Int64,Int64,Int64,Vector}}}(
    2 => (comp_id = 2, parent_id = -1, child_nr = -1, type = 2, children = [3, 5]),
    3 => (comp_id = 2, parent_id = 2, child_nr = 1, type = 2, children = []),
    5 => (comp_id = 2, parent_id = 2, child_nr = 2, type = 4, children = []),
    7 => (comp_id = 7, parent_id = -1, child_nr = -1, type = 0, children = [8,9]),
    8 => (comp_id = 7, parent_id = 7, child_nr = 0, type = 1, children = []),
    9 => (comp_id = 7, parent_id = 7, child_nr = 1, type = 1, children = []),
)
c_ast = ["assign(2, x)", "assign(3, x)", "assign(5, x)", "assign(8, x)", "assign(9, x)", "assign(7, x)", "assign(8, x)", "assign(9, x)", "assign(7, x)"]

# c_info = analyze_AST_singular(Subtree_dict, c_ast)

# println("compression information")
# for (k,v) in c_info
#     println("compression ", k)
#     println(v)
#     println()
# end


###################### COMBINE COMPRESSION STATISTICS #############################

Base.isequal(k1::RuleNode, k2::RuleNode) = compare(k1, k2) #k1.field1 == k2.field1 && k1.field2 == k2.field2
# Base.hash(k::RuleNode, h::UInt) = hash((k.field1, k.field2), h)

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

# dictionary1 = Dict{Int64, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}(
#     0 => (size = 3, occurences = 4),
#     1 => (size = 1, occurences = 1),
#     2 => (size = 4, occurences = 6),
#     3 => (size = 2, occurences = 4),
#     4 => (size = 3, occurences = 2))

# dictionary2 = Dict{Int64, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}(
#     0 => (size = 3, occurences = 2),
#     1 => (size = 1, occurences = 1),
#     3 => (size = 2, occurences = 1),
#     4 => (size = 3, occurences = 2),
#     5 => (size = 2, occurences = 2))

# dictionary3 = Dict{Int64, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}()

# total_dict = combine_comp_stats(Vector{}([dictionary1, dictionary2, dictionary3]))
# println("total dict: ", total_dict)


function select_compressions(case, c, f_best)
    """
    Selects the best compressions according to some heuristic.
    # Arguments
    - `case::Int64`: the heuristic to use (1: occurences, 2: occurences * size)
    - `c::Dict{RuleNode, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}`: a dictionary (key: compression (RuleNode), value: tuple(size, # occurences))
    - `f_best::Float64`: a float in range [0,1], that specifies what proportion of the compressions will get selected
    # Result
    - `c::Vector{RuleNode}`: a sorted and filtered list of compression IDs
    """
    # change here for the heuristics
    # case = 2

    # sorting the dictionary
    # case 1: occurences
    if case == 1
        println("sorting by #occurences...")
        c = sort(collect(c), by=x->x[2].occurences, rev=true) # decreasing order of value

        # for (k,v) in c
        #     print("score ", v.occurences)
        #     println(": ", k, " ", v)
        # end
    # case 2: occurences * size
    elseif  case ==2
        println("sorting by #occurences * tree_size...")
        c = sort(collect(c), by=x->(x[2].occurences * x[2].size), rev=true) # decreasing order of value

        # for (k,v) in c
        #     print("score ", v.occurences * v.size)
        #     println(": ", k, " ", v,)
        # end
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


###################### EXAMPLE USAGE #############################

# dictionary1 = Dict{Int64, NamedTuple{(:size,:occurences), <:Tuple{Int64,Int64}}}(
#     0 => (size = 3, occurences = 2),
#     1 => (size = 1, occurences = 1),
#     2 => (size = 4, occurences = 0),
#     3 => (size = 2, occurences = 1),
#     4 => (size = 3, occurences = 2),
#     5 => (size = 2, occurences = 2))


# select_compression(dictionary1, 0.45) 