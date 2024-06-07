"""
    resolve_angelic!(
        program::RuleNode, passing_tests::BitVector, grammar::AbstractGrammar, symboltable::SymbolTable, tests::AbstractVector{<:IOExample}, 
        replacement_func::Function, angelic_conditions::Dict{UInt16,UInt8}, config::FrAngelConfig, fragment_base_rules_offset::Int16,
        rule_minsize::AbstractVector{UInt8}, symbol_minsize::Dict{Symbol,UInt8})::RuleNode

Resolve angelic conditions in the given program by generating random boolean expressions and replacing the holes in the expression.
The program is modified in-place.

# Arguments
- `program`: The program to resolve angelic conditions in.
- `passing_tests`: A BitVector representing the tests that the program has already passed.
- `grammar`: The grammar rules of the program.
- `symboltable`: A symbol table for the grammar.
- `tests`: A vector of `IOExample` objects representing the input-output test cases.
- `replacement_func`: The function to use for replacement -> either `replace_first_angelic!` or `replace_last_angelic!`.
- `angelic_conditions`: A dictionary mapping indices of angelic condition candidates, to the child index that may be changed.
- `config`: The configuration object for FrAngel.
- `fragment_base_rules_offset`: The offset for fragment base/identity rules.
- `rule_minsize`: A vector of minimum sizes for each production rule in the grammar. Can be obtained from [`rules_minsize`](@ref).
- `symbol_minsize`: A dictionary with the minimum size achievable for each symbol in the grammar. Can be obtained from [`symbols_minsize`](@ref).

# Returns
The resolved program with angelic values replaced, or an unresolved program if it times out.

"""
function resolve_angelic!(
    program::RuleNode,
    passing_tests::BitVector,
    grammar::AbstractGrammar,
    symboltable::SymbolTable,
    tests::AbstractVector{<:IOExample},
    replacement_func::Function,
    angelic_conditions::Dict{UInt16,UInt8},
    config::FrAngelConfig,
    fragment_base_rules_offset::Int16,
    rule_minsize::AbstractVector{UInt8},
    symbol_minsize::Dict{Symbol,UInt8}
)::RuleNode
    num_holes = number_of_holes(program)
    angelic = config.angelic
    new_tests = BitVector([false for _ in tests])
    # Continue resolution until all holes are filled
    while num_holes != 0
        success = false
        start_time = time()
        max_time = config.angelic.max_time
        # Keep track of visited replacements - avoid duplicates
        visited = init_long_hash_map()
        while time() - start_time < max_time
            # Generate a replacement
            boolean_expr = generate_random_program(grammar, :Bool, config.generation, fragment_base_rules_offset, angelic.boolean_expr_max_size,
                rule_minsize, symbol_minsize)
            program_hash = hash(boolean_expr)
            if lhm_contains(visited, program_hash)
                continue
            end
            lhm_put!(visited, program_hash)
            # Either replace 'first' or 'last' hole
            changed = replacement_func(program, boolean_expr, config.angelic.angelic_rulenode, angelic_conditions)
            update_passed_tests!(program, grammar, symboltable, tests, new_tests, angelic_conditions, angelic)
            # If the new program passes all the tests the original program did, replacement is successful
            if all(passing_tests .== (passing_tests .& new_tests))
                passing_tests = new_tests
                success = true
                break
            else
                # Undo replacement changes
                changed[1].children[changed[2]] = changed[3]
            end
        end
        # Unresolved -> try other direction, or fail
        if !success && replacement_func == replace_last_angelic!
            return program
        elseif !success
            return resolve_angelic!(program, passing_tests, grammar, symboltable, tests, replace_last_angelic!, angelic_conditions, config,
                fragment_base_rules_offset, rule_minsize, symbol_minsize)
        else
            num_holes -= 1
        end
    end
    return program
end

"""
    replace_first_angelic!(program::RuleNode, boolean_expr::RuleNode, angelic_rulenode::RuleNode, angelic_conditions::Dict{UInt16,UInt8})
        ::Union{Tuple{RuleNode,Int,AbstractHole},Nothing}

Replaces the first `AbstractHole` node in the `program` with the `boolean_expr` node. 
The 'first' is defined here as the first node visited by pre-order traversal, left-to-right. The program is modified in-place.

# Arguments
- `program`: The program to resolve angelic conditions in.
- `boolean_expr`: The boolean expression node to replace the `AbstractHole` node with.
- `angelic_rulenode`: The angelic rulenode. Used to compare against nodes in the program.
- `angelic_conditions`: A dictionary mapping indices of angelic condition candidates, to the child index that may be changed.

# Returns
The parent node, the index of its modified child, and the modification. Used to clear the changes if replacement is unsuccessful.

"""
function replace_first_angelic!(
    program::RuleNode,
    boolean_expr::RuleNode,
    angelic_rulenode::RuleNode,
    angelic_conditions::Dict{UInt16,UInt8}
)::Union{Tuple{RuleNode,Int,AbstractHole},Nothing}
    angelic_index = get(angelic_conditions, program.ind, -1)
    for (child_index, child) in enumerate(program.children)
        if child_index == angelic_index && child isa AbstractHole
            program.children[child_index] = boolean_expr
            return (program, child_index, child)
        else
            res = replace_first_angelic!(child, boolean_expr, angelic_rulenode, angelic_conditions)
            if res !== nothing
                return res
            end
        end
    end
    return nothing
end


"""
    replace_last_angelic!(program::RuleNode, boolean_expr::RuleNode, angelic_rulenode::RuleNode, angelic_conditions::Dict{UInt16,UInt8})
        ::Union{Tuple{RuleNode,Int,AbstractHole},Nothing}

Replaces the last `AbstractHole` node in the `program` with the `boolean_expr` node. 
The 'last' is defined here as the first node visited by reversed pre-order traversal (right-to-left). The program is modified in-place.

# Arguments
- `program`: The program to resolve angelic conditions in.
- `boolean_expr`: The boolean expression node to replace the `AbstractHole` node with.
- `angelic_rulenode`: The angelic rulenode. Used to compare against nodes in the program.
- `angelic_conditions`: A dictionary mapping indices of angelic condition candidates, to the child index that may be changed.

# Returns
The parent node, the index of its modified child, and the modification. Used to clear the changes if replacement is unsuccessful.

"""
function replace_last_angelic!(
    program::RuleNode,
    boolean_expr::RuleNode,
    angelic_rulenode::RuleNode,
    angelic_conditions::Dict{UInt16,UInt8}
)::Union{Tuple{RuleNode,Int,AbstractHole},Nothing}
    angelic_index = get(angelic_conditions, program.ind, -1)
    # Store indices to go over them backwards later
    indices = Vector{Int}([])
    for child_index in reverse(eachindex(program.children))
        child = program.children[child_index]
        if child_index == angelic_index && child isa AbstractHole
            program.children[child_index] = boolean_expr
            return (program, child_index, child)
        else
            push!(indices, child_index)
        end
    end
    # If no angelic in this layer, continue onto lower layers, in reverse
    for child_index in indices
        res = replace_last_angelic!(program.children[child_index], boolean_expr, angelic_rulenode, angelic_conditions)
        if res !== nothing
            return res
        end
    end
    return nothing
end

"""
    execute_angelic_on_input(
        symboltable::SymbolTable, program::RuleNode, grammar::AbstractGrammar, input::Dict{Symbol,Any}, 
        expected_output::Any, angelic_rulenode::RuleNode, max_attempts::Int, angelic_conditions::Dict{UInt16,UInt8})::Bool

Run test case `input` on `program` containing angelic conditions. This is done by optimistically evaluating the program, by generating different code paths
    and checking if any of them make the program pass the test case.

# Arguments
- `symboltable`: The symbol table containing the program's symbols.
- `program`: The program to be executed.
- `grammar`: The grammar rules of the program.
- `input`: A dictionary where each key is a symbol used in the expression, and the value is the corresponding value to be used in the expression's evaluation.
- `expected_output`: The expected output of the program.
- `angelic_rulenode`: The angelic rulenode. It is used to replace angelified conditions.
- `max_attempts`: The maximum number of attempts before assuming the angelic program cannot be resolved.
- `angelic_conditions`: A dictionary mapping indices of angelic condition candidates, to the child index that may be changed.

# Returns
Whether the output of running `program` on `input` matches `output` within `max_attempts` attempts.

"""
function execute_angelic_on_input(
    symboltable::SymbolTable,
    program::RuleNode,
    grammar::AbstractGrammar,
    input::Dict{Symbol,Any},
    expected_output::Any,
    angelic_rulenode::RuleNode,
    max_attempts::Int,
    angelic_conditions::Dict{UInt16,UInt8}
)::Bool
    num_true, attempts = 0, 0
    # We check traversed code paths by prefix -> trie is efficient for this
    visited = BitTrie()
    expr = create_angelic_expression(program, grammar, angelic_rulenode, angelic_conditions)
    while num_true < max_attempts
        code_paths = Vector{BitVector}()
        get_code_paths!(num_true, BitVector(), visited, code_paths, max_attempts - attempts)
        # Terminate if we generated max_attempts, or impossible to generate further paths
        if isempty(code_paths)
            return false
        end
        for code_path in code_paths
            # println("Attempt: ", code_path)
            actual_code_path = BitVector()
            try
                output = execute_on_input(symboltable, expr, input, CodePath(code_path, 0), actual_code_path)
                # println("Actual path: ", actual_code_path)
                if test_output_equality(output, expected_output)
                    return true
                end
            catch
            # Mark as visited and count attempt
            finally
                trie_add!(visited, actual_code_path)
                attempts += 1
            end
        end
        num_true += 1
    end
    false
end

"""
    get_code_paths!(num_true::Int, curr::BitVector, visited::BitTrie, code_paths::Vector{BitVector}, max_length::Int)

Generate code paths to be used for angelic evaluation, and stores them in `code_paths`. The function recursively explores different sequences of `true` and `false` 
    values, which represent whether the next control statement will be skipped or not. Makes sure that the returned paths do not share prefix with visited paths.

# Arguments
- `num_true`: The number of `true` values in the code path.
- `curr`: The current code path being generated.
- `visited`: The visited code paths.
- `code_paths`: The vector to store the generated code paths.
- `max_length`: The maximum length of a code path allowed.

"""
function get_code_paths!(
    num_true::Int,
    curr::BitVector,
    visited,
    code_paths::Vector{BitVector},
    max_length::Int
)
    # If enough code paths, or visited a prefix-path, return
    if (length(code_paths) >= max_length || trie_contains(visited, curr))
        return
    end
    # Add current one if enough 'true' values
    if num_true == 0
        push!(code_paths, deepcopy(curr))
        return
    end
    # Continue with 'true' and build all paths
    push!(curr, true)
    get_code_paths!(num_true - 1, curr, visited, code_paths, max_length)
    # Continue with 'false' and build all paths
    curr[end] = false
    get_code_paths!(num_true, curr, visited, code_paths, max_length)
    pop!(curr)
end

"""
    create_angelic_expression(program::RuleNode, grammar::AbstractGrammar, angelic_rulenode::RuleNode, angelic_conditions::Dict{UInt16,UInt8})::Expr

Create an angelic expression, i.e. replace all remaining holes with angelic rulenode trees so that the tree can be parsed and executed.

# Arguments
- `program`: The program to turn into an angelic expression.
- `grammar`: The grammar rules of the program.
- `angelic_rulenode`: The angelic rulenode. It is used to replace angelified conditions.
- `angelic_conditions`: A dictionary mapping indices of angelic condition candidates, to the child index that may be changed.

# Returns
The generated angelic expression.

"""
function create_angelic_expression(
    program::RuleNode,
    grammar::AbstractGrammar,
    angelic_rulenode::RuleNode,
    angelic_conditions::Dict{UInt16,UInt8}
)::Expr
    new_program = deepcopy(program)
    # BFS traversal
    queue = DataStructures.Queue{AbstractRuleNode}()
    enqueue!(queue, new_program)
    while !isempty(queue)
        node = dequeue!(queue)
        angelic_idx = get(angelic_conditions, node.ind, -1)
        for (child_index, child) in enumerate(node.children)
            if angelic_idx == child_index && child isa AbstractHole
                node.children[child_index] = angelic_rulenode
            else
                enqueue!(queue, child)
            end
        end
    end
    rulenode2expr(new_program, grammar)
end