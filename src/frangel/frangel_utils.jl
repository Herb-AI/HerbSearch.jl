"""
    random_partition(grammar::AbstractGrammar, rule_index::Int16, size::UInt8, symbol_minsize::Dict{Symbol,Int})::AbstractVector{UInt8}

Randomly partitions the allowed size into a vector of sizes for each child of the provided rule index.

# Arguments
- `grammar`: The grammar rules of the program.
- `rule_index`: The index of the rule to partition.
- `size`: The size to partition.
- `symbol_minsize`: A dictionary with the minimum size achievable for each symbol in the grammar. Can be obtained from [`symbols_minsize`](@ref).

# Returns
A vector of sizes for each child of the provided rule index.

"""
function random_partition(grammar::AbstractGrammar, rule_index::Int16, size::UInt8, symbol_minsize::Dict{Symbol,UInt8})::AbstractVector{UInt8}
    children_types = child_types(grammar, Int(rule_index))
    # Calculate remainder (total -  minimal size needed for this rule, aka. sum of all its children's minimal sizes)
    min_size = sum(symbol_minsize[child_type] for child_type in children_types)
    left_to_partition = size - min_size
    # Partition the remaining size randomly among children
    sizes = Vector{UInt8}(undef, length(children_types))
    for (index, child_type) in enumerate(children_types)
        # Give each children a random size between minimal and minimal + total remainder
        child_min_size = symbol_minsize[child_type]
        partition_size = rand(child_min_size:(child_min_size+left_to_partition))
        # Update sizes and remainder
        sizes[index] = partition_size
        left_to_partition -= (partition_size - child_min_size)
    end
    sizes
end

"""
    simplify_quick(program::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, passed_tests::BitVector, fragment_base_rules_offset::Int16)::RuleNode

Simplifies the provided program by replacing nodes with smaller nodes that pass the same tests. The program is updated in-place.

# Arguments
- `program`: The program to simplify.
- `grammar`: The grammar rules of the program.
- `tests`: A vector of `IOExample` objects representing the input-output test cases.
- `passed_tests`: A BitVector representing the tests that the program has already passed.
- `fragment_base_rules_offset`: The offset for fragment base/identity rules.

# Returns
The simplified program.

"""
function simplify_quick(program::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, passed_tests::BitVector, fragment_base_rules_offset::Int16)::RuleNode
    simlified = _simplify_quick_once(program, program, grammar, tests, passed_tests, fragment_base_rules_offset, Vector{Int}())
    # Continuously simplify program until unchanged
    while program != simlified
        program = simlified
        simlified = _simplify_quick_once(program, program, grammar, tests, passed_tests, fragment_base_rules_offset, Vector{Int}())
    end
    program
end

"""
    _simplify_quick_once(
        root::RuleNode, node::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, 
        passed_tests::BitVector, path::Vector{Int}=[])::RuleNode

The recursive one-call function for simplifying a program.

# Arguments
- `root`: The root node from which the simplification started.
- `node`: The current node to be simplified.
- `grammar`: The grammar rules of the program.
- `tests`: A vector of `IOExample` objects representing the input-output test cases.
- `passed_tests`: A `BitVector` representing the tests that the program has previously passed.
- `path`: The path from the root node to the current node.

# Returns
The simplified program.

"""
function _simplify_quick_once(
    root::RuleNode,
    node::RuleNode,
    grammar::AbstractGrammar,
    tests::AbstractVector{<:IOExample},
    passed_tests::BitVector,
    fragment_base_rules_offset::Int16,
    path::Vector{Int}=[]
)::RuleNode
    # Try each replacement, by checking if it passes a superset of original tests
    for replacement in get_replacements(node, grammar, fragment_base_rules_offset)
        if length(path) == 0
            if passes_the_same_tests_or_more(replacement, grammar, tests, passed_tests)
                return replacement
            end
        else
            swap_node(root, replacement, path)
            if passes_the_same_tests_or_more(root, grammar, tests, passed_tests)
                return replacement
            end
            swap_node(root, node, path)
        end
    end
    # Revert swap of higher nodes
    if length(path) > 0
        swap_node(root, node, path)
    end
    # If already reached leaves, terminate
    if isterminal(grammar, node)
        return node
        # Else recurse to try simplifying children
    else
        for (index, child) in enumerate(node.children)
            node.children[index] = _simplify_quick_once(root, child, grammar, tests, passed_tests, fragment_base_rules_offset, [path; index])
        end
    end
    node
end



"""
    symbols_minsize(grammar::AbstractGrammar, min_sizes::AbstractVector{Int})::Dict{Symbol,Int}

Returns a dictionary with pairs of starting symbol type and the minimum size achievable from it.

# Arguments
- `grammar`: The grammar rules of the program.
- `min_sizes`: A vector of minimum sizes for each production rule in the grammar. Can be obtained from [`rules_minsize`](@ref).

# Returns
Dictionary with the minimum size achievable for each symbol in the grammar.

"""
function symbols_minsize(grammar::AbstractGrammar, min_sizes::AbstractVector{UInt8})::Dict{Symbol,UInt8}
    Dict(type => minimum(min_sizes[grammar.bytype[type]]) for type in grammar.types)
end

"""
    rules_minsize(grammar::AbstractGrammar)::AbstractVector{Int}

Returns the minimum size achievable for each production rule in the [`AbstractGrammar`](@ref).
In other words, this function finds the size of the smallest trees that can be made 
using each of the available production rules as a root.

# Arguments
- `grammar`: The grammar rules of the program.

# Returns
The minimum size achievable for each production rule in the grammar, in the same order as the rules.

"""
function rules_minsize(grammar::AbstractGrammar)::Vector{UInt8}
    temp = Union{UInt8,Nothing}[nothing for _ in eachindex(grammar.rules)]

    for i in eachindex(grammar.rules)
        if isterminal(grammar, i)
            temp[i] = 1
        end
    end

    max_tries = length(grammar.rules)
    while any(isnothing, temp) && max_tries > 0
        for i in eachindex(grammar.rules)
            if isnothing(temp[i])
                size = UInt8(1)

                for ctyp in child_types(grammar, i)
                    min_child_size = nothing

                    for index in grammar.bytype[ctyp]
                        if !isnothing(temp[index])
                            if isnothing(min_child_size)
                                min_child_size = temp[index]
                            else
                                min_child_size = min(min_child_size, temp[index])
                            end
                        end
                    end
                    if isnothing(min_child_size)
                        @goto next_rule
                    else
                        size += min_child_size
                    end
                end

                temp[i] = size
                @label next_rule
            end
        end
        max_tries -= 1
    end

    if any(isnothing, temp)
        throw(ArgumentError("Could not calculate minimum sizes for all rules"))
    else
        min_sizes = UInt8[255 for _ in eachindex(grammar.rules)]

        for i in eachindex(grammar.rules)
            min_sizes[i] = temp[i]
        end

        min_sizes
    end
end

"""
    update_min_sizes!(
        grammar::AbstractGrammar, fragment_base_rules_offset::Int16, fragment_rules_offset::Int16,
        fragments::AbstractVector{RuleNode}, rule_minsize::AbstractVector{UInt8}, symbol_minsize::Dict{Symbol,UInt8})

Updates the minimum sizes of the rules and symbols in the grammar. Called after adding the new fragment rules.

# Arguments
- `grammar`: The grammar rules of the program.
- `fragment_base_rules_offset`: The offset for fragment base/identity rules.
- `fragment_rules_offset`: The offset for fragment rules.
- `fragments`: A set of the fragments mined to update the grammar iwth.
- `rule_minsize`: A vector of minimum sizes for each production rule in the grammar. Can be obtained from [`rules_minsize`](@ref).
- `symbol_minsize`: A dictionary with the minimum size achievable for each symbol in the grammar. Can be obtained from [`symbols_minsize`](@ref).

"""
function update_min_sizes!(grammar::AbstractGrammar, fragment_base_rules_offset::Int16, fragment_rules_offset::Int16,
    fragments::AbstractVector{RuleNode}, rule_minsize::AbstractVector{UInt8}, symbol_minsize::Dict{Symbol,UInt8})
    # Reset symbol minsizes    
    for i in fragment_base_rules_offset+1:fragment_rules_offset
        symbol_minsize[grammar.rules[i]] = 255
    end
    # For each fragment, update its rule, and possibly the return symbol
    resize!(rule_minsize, length(grammar.rules))
    for (i, fragment) in enumerate(fragments)
        rule_minsize[fragment_rules_offset+i] = length(fragment)
        ret_typ = return_type(grammar, fragment_rules_offset + i)
        if haskey(symbol_minsize, ret_typ)
            symbol_minsize[ret_typ] = min(symbol_minsize[ret_typ], rule_minsize[fragment_rules_offset+i])
        else
            symbol_minsize[ret_typ] = rule_minsize[fragment_rules_offset+i]
        end
    end
    # Reset remaining rule minsizes
    for i in fragment_base_rules_offset+1:fragment_rules_offset
        if !isterminal(grammar, i)
            rule_minsize[i] = symbol_minsize[grammar.rules[i]]
        else
            rule_minsize[i] = 255
        end
    end

end