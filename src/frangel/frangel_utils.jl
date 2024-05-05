@kwdef struct FrAngelConfig
    max_time::Float16 = 0.1
    random_generation_max_size::Int = 40
    random_generation_use_fragments_chance::Float16 = 0.5
    use_angelic_conditions::Bool = false
    similar_new_extra_size::Int = 8
    gen_similar_prob_new::Float16 = 0.25
end


@programiterator FrAngelIterator(
    spec::Vector{<:IOExample},
    config::FrAngelConfig,
)

struct FrAngelIteratorState
    remembered_programs::Dict{BitVector, Tuple{RuleNode, Int, Int}}
    fragments::Set{RuleNode}
end

function Base.iterate(iter::FrAngelIterator)
    iterate(iter, FrAngelIteratorState(
        Dict{BitVector, Tuple{RuleNode, Int, Int}}(),
        Set{RuleNode}()
    ))
end

function Base.iterate(iter::FrAngelIterator, state::FrAngelIteratorState)
    start_time = time()

    while time() - start_time < iter.config.max_time
        generate_with_angelic = rand(Bool) && iter.config.use_angelic_conditions

        program = generate_random_program(
            iter.grammar,
            iter.sym,
            state.fragments,
            iter.config,
            generate_with_angelic,
            iter.config.random_generation_max_size
        )

        passed_tests = get_passed_tests(program, iter.grammar, iter.spec)
        if !any(passed_tests)
            continue
        end

        # if contains_angelic(program)
        #    TODO: implement angelic conditions
        # end

        program = simplify_quick(program, iter.grammar, iter.spec, passed_tests)

        passed_tests = get_passed_tests(program, iter.grammar, iter.spec)

        remember_programs!(state.remembered_programs, passed_tests, program, state.fragments, iter.grammar)

        if all(passed_tests)
            return program, state # simplify_slow(program), state
        end
    end

    return nothing
end

function get_passed_tests(program::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample})::BitVector
    symboltable = SymbolTable(grammar)
    expr = rulenode2expr(program, grammar)

    passed_tests = BitVector([false for i in tests])

    for (index, test) in enumerate(tests)
        try
            output = execute_on_input(symboltable, expr, test.in) 
            passed_tests[index] = output == test.out
        catch e
            passed_tests[index] = false
        end
    end

    passed_tests
end

"""
    mine_fragments(grammar::AbstractGrammar, program::RuleNode)::Set{RuleNode}

Finds all the fragments from the provided `program``. The result is a set of the distinct fragments found within the program. Recursively goes over all children.

# Arguments
- `grammar`: An abstract grammar object.
- `program`: The program to mine for fragments

# Returns
All the found fragments in the provided program.
"""
function mine_fragments(grammar::AbstractGrammar, program::RuleNode)::Set{RuleNode}
    fragments = Set{RuleNode}()
    if isterminal(grammar, program)
        push!(fragments, program)
    else
        if iscomplete(grammar, program)
            push!(fragments, program)
        end
        for child in program.children
            fragments = union(fragments, mine_fragments(grammar, child))
        end
    end
    return fragments
end

"""
    mine_fragments(grammar::AbstractGrammar, programs::Set{RuleNode})::Set{RuleNode}

Finds all the fragments from the provided `programs` list. The result is a set of the distinct fragments found within all programs.

# Arguments
- `grammar`: An abstract grammar object.
- `programs`: A set of programs to mine for fragments

# Returns
All the found fragments in the provided programs.
"""
function mine_fragments(grammar::AbstractGrammar, programs::Set{RuleNode})::Set{RuleNode}
    fragments = reduce(union, mine_fragments(grammar, p) for p in programs)
    for program in programs delete!(fragments, program) end
    return fragments
end

"""
    mine_fragments(grammar::AbstractGrammar, programs::Set{Tuple{RuleNode, Int, Int}})::Set{RuleNode}

Finds all the fragments from the provided `programs` list. The result is a set of the distinct fragments found within all programs.

# Arguments
- `grammar`: An abstract grammar object.
- `programs`: A set of programs to mine for fragments

# Returns
All the found fragments in the provided programs.
"""
function mine_fragments(grammar::AbstractGrammar, programs::Set{Tuple{RuleNode, Int, Int}})::Set{RuleNode}
    fragments = reduce(union, mine_fragments(grammar, p) for (p, _, _) in programs)
    for program in programs delete!(fragments, program) end
    return fragments
end

# This could potentially go somewhere else, for instance in a generic util file
"""
    count_nodes(program::RuleNode)::Int

Count the number of nodes in a given `RuleNode` program.

# Arguments
- `grammar`: An abstract grammar object.
- `program`: The `RuleNode` program to count the nodes in.

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
    remember_programs!(old_remembered::Dict{BitVector, Tuple{RuleNode, Int, Int}}, passing_tests::BitVector, new_program::RuleNode, 
        fragments::Set{RuleNode}, grammar::AbstractGrammar)::Set{RuleNode}

Updates the remembered programs by including `new_program` if it is simpler than all remembered programs that pass the same subset of tests. 
    It also removes any "worse" programs from the dictionary, and finally updated the set of fragments with the new remembered programs.

# Arguments
- `old_remembered`: A dictionary mapping BitVectors to tuples of RuleNodes, node counts, and program lengths.
- `passing_tests`: A BitVector representing the passing test set for the new program.
- `new_program`: The new program to be added to the `old_remembered` dictionary.
- `fragments`: A set of RuleNodes representing the fragments mined from the `old_remembered` dictionary.
- `grammar`: An AbstractGrammar object representing the grammar used for program generation.

# Returns
A set of RuleNodes representing the fragments mined from the updated `old_remembered` dictionary.
"""
function remember_programs!(old_remembered::Dict{BitVector, Tuple{RuleNode, Int, Int}}, passing_tests::BitVector, new_program::RuleNode, 
    fragments::Set{RuleNode}, grammar::AbstractGrammar)
    node_count = count_nodes(grammar, new_program)
    program_length = length(string(rulenode2expr(new_program, grammar)))
    # Check the new program's testset over each remembered program
    for (key_tests, (_, p_node_count, p_program_length)) in old_remembered
        isSimpler = node_count < p_node_count || (node_count == p_node_count && program_length < p_program_length)
        # if the new program's passing testset is a subset of the old program's, discard new program if worse
        if all(passing_tests .== (passing_tests .& key_tests))
            if !isSimpler
                return nothing
            end
            # else if it is a superset -> discard old program if worse (either more nodes, or same #nodes but less tests)
        elseif all(key_tests .== (key_tests .& passing_tests))
            if isSimpler || (passing_tests != key_tests && node_count == p_node_count)
                delete!(old_remembered, key_tests)
            end
        end
    end
    old_remembered[passing_tests] = (new_program, node_count, program_length)
    fragments = mine_fragments(grammar, Set(values(old_remembered)))
end

"""
    generate_random_program(grammar::AbstractGrammar, type::Symbol, fragments::Set{RuleNode}, config::FrAngelConfig, generate_with_angelic::Bool, max_size=40, disabled_fragments=false)::Union{RuleNode, Nothing}

Generates a random program of the provided `type` using the provided `grammar`. The program is generated with a maximum size of `max_size` and can use fragments from the provided set.

# Arguments
- `grammar`: An abstract grammar object.
- `type`: The type of the program to generate.
- `fragments`: A set of RuleNodes representing the fragments that can be used in the program generation.
- `config`: A FrAngelConfig object containing the configuration for the random program generation.
- `generate_with_angelic`: A boolean flag to enable the use of angelic conditions in the program generation.
- `max_size`: The maximum size of the program to generate.
- `disabled_fragments`: A boolean flag to disable the use of fragments in the program generation.

# Returns
A random program of the provided type, or nothing if no program can be generated.
"""
function generate_random_program(
    grammar::AbstractGrammar, 
    type::Symbol, 
    fragments::Set{RuleNode}, 
    config::FrAngelConfig,
    generate_with_angelic::Bool,
    max_size=40, 
    disabled_fragments=false
)::Union{RuleNode, Nothing}
    if max_size < 0
        return nothing
    end

    use_fragments = !disabled_fragments && rand() < config.random_generation_use_fragments_chance

    if use_fragments
        possible_fragments = filter(f -> return_type(grammar, f) == type, fragments)

        if !isempty(possible_fragments)
            fragment = deepcopy(rand(possible_fragments))

            if rand(Bool)
                return fragment
            end

            random_modify_children!(grammar, fragment, config, generate_with_angelic)
            return fragment
        end
    end

    minsize = rules_minsize(grammar)
    possible_rules = filter(r -> minsize[r] ≤ max_size, grammar[type])

    if isempty(possible_rules)
        return nothing
    end

    rule_index = StatsBase.sample(possible_rules)
    rule_node = RuleNode(rule_index)

    if !grammar.isterminal[rule_index]
        symbol_minsize = symbols_minsize(grammar, minsize)
        sizes = random_partition(grammar, rule_index, max_size, symbol_minsize)

        for (index, child_type) in enumerate(child_types(grammar, rule_index))
            push!(rule_node.children, generate_random_program(grammar, child_type, fragments, config, generate_with_angelic, sizes[index], disabled_fragments))
        end
    end

    rule_node
end


# This could potentially go somewhere else, for instance in a generic util file
"""
    random_partition(grammar::AbstractGrammar, rule_index::Int, size::Int, symbol_minsize::Dict{Symbol,Int})::AbstractVector{Int}

Randomly partitions the allowed size into a vector of sizes for each child of the provided rule index.

# Arguments
- `grammar`: An abstract grammar object.
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
    random_modify_children!(grammar::AbstractGrammar, node::RuleNode, config::FrAngelConfig, generate_with_angelic::Bool)

Randomly modifies the children of a given node. The modification can be either a new random program or a modification of the existing children.

# Arguments
- `grammar`: An abstract grammar object.
- `node`: The node to modify the children of.
- `config`: A FrAngelConfig object containing the configuration for the random modification.
- `generate_with_angelic`: A boolean flag to enable the use of angelic conditions in the program generation.

# Returns
Modifies the `node` directly.
"""
function random_modify_children!(grammar::AbstractGrammar, node::RuleNode, config::FrAngelConfig, generate_with_angelic::Bool)
    for (index, child) in enumerate(node.children)
        if rand() < config.gen_similar_prob_new
            node.children[index] = generate_random_program(grammar, return_type(grammar, child), Set{RuleNode}(), config, generate_with_angelic, count_nodes(grammar, child) + config.similar_new_extra_size, true)
        else
            random_modify_children!(grammar, child, config, generate_with_angelic)
        end
    end
end

"""
    simplify_quick(program::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, passed_tests::BitVector)::RuleNode

Simplifies the provided program by replacing nodes with smaller nodes that pass the same tests.

# Arguments
- `program`: The program to simplify.
- `grammar`: An abstract grammar object.
- `tests`: A vector of IOExamples to test the program on.
- `passed_tests`: A BitVector representing the tests that the program has already passed.

# Returns
The simplified program.
"""
function simplify_quick(program::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, passed_tests::BitVector)::RuleNode
    simlified = _simplify_quick_once(program, program, grammar, tests, passed_tests)

    while program != simlified
        program = simlified
        simlified = _simplify_quick_once(program, program, grammar, tests, passed_tests)
    end

    program
end

function _simplify_quick_once(
    root::RuleNode,
    node::RuleNode,
    grammar::AbstractGrammar,
    tests::AbstractVector{<:IOExample},
    passed_tests::BitVector
)::RuleNode
    for replacement in get_replacements(node, grammar)
        initial = node
        node = replacement
        if passes_the_same_tests_or_more(root, grammar, tests, passed_tests)
            return replacement
        end
        node = initial
    end

    if isterminal(grammar, node)
        return node
    else
        for child in node.children
            child = _simplify_quick_once(root, child, grammar, tests, passed_tests)
        end
    end

    node
end

# This could potentially go somewhere else, for instance in a generic util file
"""
    get_replacements(node::RuleNode, grammar::AbstractGrammar)::AbstractVector{RuleNode}

Finds all the possible replacements for a given node in the AST. 
Looks for single-node trees corresponding to all variables and constants in the grammar, and node descendants of the same symbol.

# Arguments
- `node`: The node to find replacements for.
- `grammar`: An abstract grammar object.

# Returns
A vector of RuleNodes representing all the possible replacements for the provided node, ordered by size.
"""
function get_replacements(node::RuleNode, grammar::AbstractGrammar)::AbstractVector{RuleNode}
    replacements = Set{RuleNode}([node])
    symbol = return_type(grammar, node)

    # The empty tree, if N⊤ is a statement in a block.
    # TODO

    # Single-node trees corresponding to all variables and constants in the grammar.
    for rule_index in eachindex(grammar.rules)
        if isterminal(grammar, rule_index) && grammar.types[rule_index] == symbol
            push!(replacements, RuleNode(rule_index))
        end
    end

    # D⊤ for all descendant nodes D of N.
    get_descendant_replacements!(node, symbol, grammar, replacements)

    sort!(collect(replacements), by=x -> count_nodes(grammar, x))
end

# This could potentially go somewhere else, for instance in a generic util file
"""
    get_descendant_replacements!(node::RuleNode, symbol::Symbol, grammar::AbstractGrammar, replacements::AbstractSet{RuleNode})

Finds all the descendants of the same symbol for a given node in the AST.

# Arguments
- `node`: The node to find descendants in.
- `symbol`: The symbol to find descendants for.
- `grammar`: An abstract grammar object.
- `replacements`: A set of RuleNodes to add the descendants to.

# Returns
Updates the `replacements` set with all the descendants of the same symbol for the provided node.
"""
function get_descendant_replacements!(node::RuleNode, symbol::Symbol, grammar::AbstractGrammar, replacements::AbstractSet{RuleNode})
    for child in node.children
        if return_type(grammar, child) == symbol
            push!(replacements, deepcopy(child))
        end
        get_descendant_replacements!(child, symbol, grammar, replacements)
    end
end

# This could potentially go somewhere else, for instance in a generic util file
"""
    passes_the_same_tests_or_more(node::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, passed_tests::BitVector)::Bool

Checks if the provided program passes all the tests that have been marked as passed.

# Arguments
- `program`: The program to test.
- `grammar`: The abstract grammar object.
- `tests`: A vector of IOExamples to test the program on.
- `passed_tests`: A BitVector representing the tests that the program has already passed.

# Returns
Returns true if the program passes all the tests that have been marked as passed, false otherwise.
"""
function passes_the_same_tests_or_more(program::RuleNode, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, passed_tests::BitVector)::Bool
    symboltable = SymbolTable(grammar)
    expr = rulenode2expr(program, grammar)

    for (index, test) in enumerate(tests)
        if !passed_tests[index]
            continue
        end

        try
            output = execute_on_input(symboltable, expr, test.in)
            if (output != test.out)
                return false
            end
        catch _
            return false
        end
    end

    return true
end

# This could potentially go somewhere else, for instance in a generic util file
"""
    symbols_minsize(grammar::AbstractGrammar, typ::Symbol, minsize_map::AbstractVector{Int})::Dict{Symbol,Int}

Returns a dictionary with pairs of starting symbol type and the minimum size achievable from it.

# Arguments
- `grammar`: An abstract grammar object.
- `min_sizes`: A vector of minimum sizes for each production rule in the grammar. Can be obtained from [`rules_minsize`](@ref).

# Returns
Dictionary with the minimum size achievable for each symbol in the grammar.
"""
function symbols_minsize(grammar::AbstractGrammar, min_sizes::AbstractVector{Int})::Dict{Symbol,Int}
    Dict(type => minimum(min_sizes[grammar.bytype[type]]) for type in grammar.types)
end

# This could potentially go somewhere else, for instance in a generic util file
"""
    rules_minsize(grammar::AbstractGrammar)::AbstractVector{Int}

Returns the minimum size achievable for each production rule in the [`AbstractGrammar`](@ref).
In other words, this function finds the size of the smallest trees that can be made 
using each of the available production rules as a root.

# Arguments
- `grammar`: An abstract grammar object.

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

# This could potentially go somewhere else, for instance in a generic util file
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