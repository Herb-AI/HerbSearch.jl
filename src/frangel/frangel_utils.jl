"""
    get_passed_tests!(program::RuleNode, grammar::AbstractGrammar, symboltable::SymbolTable, tests::AbstractVector{<:IOExample},
        prev_passed_tests::BitVector, angelic_conditions::AbstractVector{Union{Nothing,Int}}, config::FrAngelConfigAngelic)

Runs the program with all provided tests, and updates the `prev_passed_tests` vector with the results.

# Arguments
- `program`: The program to be tested.
- `grammar`: The grammar rules of the program.
- `symboltable`: A symbol table for the grammar.
- `tests`: A vector of `IOExample` objects representing the input-output test cases.
- `prev_passed_tests`: A `BitVector` representing the tests that the program has previously passed.
- `angelic_conditions`: A vector of integers representing the index of the child to replace with an angelic condition for each rule. 
    If there is no angelic condition for a rule, the value is set to `nothing`.
- `config`: The configuration for angelic conditions of FrAngel.

"""
function get_passed_tests!(
    program::RuleNode,
    grammar::AbstractGrammar,
    symboltable::SymbolTable,
    tests::AbstractVector{<:IOExample},
    prev_passed_tests::BitVector,
    angelic_conditions::AbstractVector{Union{Nothing,Int}},
    config::FrAngelConfigAngelic
)
    # If angelic -> evaluate optimistically
    if contains_hole(program)
        fails = 0
        for (index, test) in enumerate(tests)
            prev_passed_tests[index] = execute_angelic_on_input(symboltable, program, grammar, test.in, output, config.max_execute_attempts, angelic_conditions)
            if prev_passed_tests[index]
                fails += 1
                if config.max_allowed_fails < fails / length(tests)
                    return BitVector([false for i in tests])
                end
            end
        end
    else
        expr = rulenode2expr(program, grammar)
        for (index, test) in enumerate(tests)
            try
                output = execute_on_input(symboltable, expr, test.in)
                prev_passed_tests[index] = output == test.out
            catch _
                prev_passed_tests[index] = false
            end
        end
    end
end

"""
    count_nodes(program::RuleNode)::Int

Count the number of nodes in a given `RuleNode` program.

# Arguments
- `grammar`: The grammar rules of the program.
- `program`: The program to count the nodes of.

# Returns
The number of nodes in the program's AST representation.

"""
function count_nodes(grammar::AbstractGrammar, program::RuleNode)::Int
    if isterminal(grammar, program)
        return 1
    else
        return 1 + sum(count_nodes(grammar, c) for c in program.children)
    end
end

"""
    random_partition(grammar::AbstractGrammar, rule_index::Int, size::Int, symbol_minsize::Dict{Symbol,Int})::AbstractVector{Int}

Randomly partitions the allowed size into a vector of sizes for each child of the provided rule index.

# Arguments
- `grammar`: The grammar rules of the program.
- `rule_index`: The index of the rule to partition.
- `size`: The size to partition.
- `symbol_minsize`: A dictionary with the minimum size achievable for each symbol in the grammar. Can be obtained from [`symbols_minsize`](@ref).

# Returns
A vector of sizes for each child of the provided rule index.

"""
function random_partition(grammar::AbstractGrammar, rule_index::Int, size::Int, symbol_minsize::Dict{Symbol,Int})::AbstractVector{Int}
    children_types = child_types(grammar, rule_index)

    min_size = sum(symbol_minsize[child_type] for child_type in children_types)
    left_to_partition = size - min_size

    sizes = Vector{Int}(undef, length(children_types))

    for (index, child_type) in enumerate(children_types)
        child_min_size = symbol_minsize[child_type]
        partition_size = rand(child_min_size:(child_min_size+left_to_partition))

        sizes[index] = partition_size

        left_to_partition -= (partition_size - child_min_size)
    end

    sizes
end

"""
    simplify_quick(program::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, passed_tests::BitVector)::RuleNode

Simplifies the provided program by replacing nodes with smaller nodes that pass the same tests.

# Arguments
- `program`: The program to simplify.
- `grammar`: The grammar rules of the program.
- `tests`: A vector of `IOExample` objects representing the input-output test cases.
- `passed_tests`: A BitVector representing the tests that the program has already passed.

# Returns
The simplified program.

"""
function simplify_quick(program::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, passed_tests::BitVector)::RuleNode
    simlified = _simplify_quick_once(program, program, grammar, tests, passed_tests, Vector{Int}())
    # Continuously simplify program until unchanged
    while program != simlified
        program = simlified
        simlified = _simplify_quick_once(program, program, grammar, tests, passed_tests, Vector{Int}())
    end

    program
end


"""
    _simplify_quick_once(root::RuleNode, node::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, 
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
    path::Vector{Int}=[]
)::RuleNode
    for replacement in (node, grammar)
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

    if length(path) > 0
        swap_node(root, node, path)
    end

    if isterminal(grammar, node)
        return node
    else
        for (index, child) in enumerate(node.children)
            node.children[index] = _simplify_quick_once(root, child, grammar, tests, passed_tests, [path; index])
        end
    end

    node
end

"""
    passes_the_same_tests_or_more(program::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, passed_tests::BitVector)::Bool

Checks if the provided program passes all the tests that have been marked as passed.

# Arguments
- `program`: The program to test.
- `grammar`: The grammar rules of the program.
- `tests`: A vector of `IOExample` objects representing the input-output test cases.
- `passed_tests`: A BitVector representing the tests that the program has already passed.

# Returns
Returns true if the program passes all the tests that have been marked as passed, false otherwise.
    
"""
function passes_the_same_tests_or_more(program::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, passed_tests::BitVector)::Bool
    symboltable = SymbolTable(grammar)
    expr = rulenode2expr(program, grammar)
    for (index, test) in enumerate(tests)
        # If original does not pass, then skip
        if !passed_tests[index]
            continue
        end
        # Else check that new program also passes the test
        try
            output = execute_on_input(symboltable, expr, test.in)
            if (output != test.out)
                return false
            end
        catch _
            return false
        end
    end
    true
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
function symbols_minsize(grammar::AbstractGrammar, min_sizes::AbstractVector{Int})::Dict{Symbol,Int}
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
function rules_minsize(grammar::AbstractGrammar)::AbstractVector{Int}
    min_sizes = Int[typemax(Int) for i in eachindex(grammar.rules)]
    visited = Dict(type => false for type in grammar.types)

    for i in eachindex(grammar.rules)
        if isterminal(grammar, i)
            min_sizes[i] = 1
        end
    end

    for i in eachindex(grammar.rules)
        if !isterminal(grammar, i)
            min_sizes[i] = _minsize!(grammar, i, min_sizes, visited)
        end
    end
    min_sizes
end

function _minsize!(grammar::AbstractGrammar, rule_index::Int, min_sizes::AbstractVector{Int}, visited::Dict{Symbol,Bool})::Int
    isterminal(grammar, rule_index) && return 1

    size = 1
    for ctyp in child_types(grammar, rule_index)
        if visited[ctyp]
            return minimum(min_sizes[i] for i in grammar.bytype[ctyp])
        end
        visited[ctyp] = true
        rules = grammar.bytype[ctyp]
        min = typemax(Int)
        for index in rules
            min = minimum([min, _minsize!(grammar, index, min_sizes, visited)])
            if min == 1
                break
            end
        end

        visited[ctyp] = false
        size += min
    end

    min_sizes[rule_index] = size
    size
end