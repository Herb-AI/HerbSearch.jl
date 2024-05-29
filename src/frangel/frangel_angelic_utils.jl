"""
    resolve_angelic!(program::RuleNode, passing_tests::BitVector, grammar::AbstractGrammar, symboltable::SymbolTable, tests::AbstractVector{<:IOExample}, 
        replacement_dir::Int, angelic_conditions::Dict{UInt16,UInt8}, config::FrAngelConfig, fragment_base_rules_offset::Int16,
        rule_minsize::AbstractVector{UInt8}, symbol_minsize::Dict{Symbol,UInt8})::RuleNode

Resolve angelic values in the given program by generating random boolean expressions and replacing the holes in the expression.

# Arguments
- `program`: The program to resolve angelic conditions in.
- `passing_tests`: A BitVector representing the tests that the program has already passed.
- `grammar`: The grammar rules of the program.
- `symboltable`: A symbol table for the grammar.
- `tests`: A vector of `IOExample` objects representing the input-output test cases.
- `replacement_dir`: The direction of replacement; 1 for top-down, -1 for bottom-up.
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
    replacement_dir::Int, # Direction of replacement; 1 -> top-down, -1 -> bottom-up
    angelic_conditions::Dict{UInt16,UInt8},
    config::FrAngelConfig,
    fragment_base_rules_offset::Int16,
    rule_minsize::AbstractVector{UInt8},
    symbol_minsize::Dict{Symbol,UInt8}
)::RuleNode
    num_holes = number_of_holes(program)
    # Which hole to be replaced; if top-down -> first one; else -> last one
    replacement_index = (replacement_dir == 1) ? 1 : (num_holes - 1)
    angelic = config.angelic
    new_tests = BitVector([false for _ in tests])
    while num_holes != 0
        success = false
        start_time = time()
        max_time = config.angelic.max_time
        visited = init_long_hash_map()
        while time() - start_time < max_time
            boolean_expr = generate_random_program(grammar, :Bool, config.generation, fragment_base_rules_offset, angelic.boolean_expr_max_size, rule_minsize, symbol_minsize)
            program_hash = hash(boolean_expr)
            if lhm_contains(visited, program_hash)
                continue
            end
            lhm_put!(visited, program_hash)
            new_program = replace_next_angelic(program, boolean_expr, replacement_index)
            get_passed_tests!(new_program, grammar, symboltable, tests, new_tests, angelic_conditions, angelic)
            # If the new program passes all the tests the original program did, replacement is successful
            if all(passing_tests .== (passing_tests .& new_tests))
                program = new_program
                passing_tests = new_tests
                success = true
                break
            end
        end
        # Unresolved -> try other direction, or fail
        if !success && replacement_dir == -1
            return program
        elseif !success
            return resolve_angelic!(program, passing_tests, grammar, symboltable, tests, -1, angelic_conditions, config, fragment_base_rules_offset, rule_minsize, symbol_minsize)
        else
            num_holes -= 1
        end
    end
    return program
end

"""
    replace_next_angelic(program::RuleNode, boolean_expr::RuleNode, replacement_index::Int)::RuleNode

Replace the `replacement_index`'th `AbstractHole` node in the `program` with the `boolean_expr` node. The tree is traversed by BFS.

# Arguments
- `program`: The program to resolve angelic conditions in.
- `boolean_expr`: The boolean expression node to replace the `AbstractHole` node with.
- `replacement_index`: The index of the occurrence to replace.

# Returns
The modified program with the replacement.

"""
function replace_next_angelic(program::RuleNode, boolean_expr::RuleNode, replacement_index::Int)::RuleNode
    new_program = deepcopy(program)
    # BFS traversal
    queue = DataStructures.Queue{AbstractRuleNode}()
    enqueue!(queue, new_program)
    while !isempty(queue)
        node = dequeue!(queue)
        for (child_index, child) in enumerate(node.children)
            if child isa AbstractHole
                if replacement_index == 1
                    node.children[child_index] = boolean_expr
                    return new_program
                else
                    replacement_index -= 1
                end
            else
                enqueue!(queue, child)
            end
        end
    end
    new_program
end

"""
    execute_angelic_on_input(symboltable::SymbolTable, program::RuleNode, grammar::AbstractGrammar, input::Dict{Symbol,Any}, 
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
        if isempty(code_paths)
            return false
        end
        for code_path in code_paths
            # println("Attempt: ", code_path)
            # Create actual_code_path here to keep reference for simpler access later
            actual_code_path = BitVector()
            try
                output = execute_on_input(symboltable, expr, input, CodePath(code_path, 0), actual_code_path)
                # println("Actual path: ", actual_code_path)
                if output == expected_output
                    return true
                end
            catch
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
    if (length(code_paths) > max_length || trie_contains(visited, curr))
        return
    end
    if num_true == 0
        push!(code_paths, deepcopy(curr))
        return
    end
    push!(curr, true)
    get_code_paths!(num_true - 1, curr, visited, code_paths, max_length)
    curr[end] = false
    get_code_paths!(num_true, curr, visited, code_paths, max_length)
    pop!(curr)
end

"""
    create_angelic_expression(program::RuleNode, grammar::AbstractGrammar, angelic_rulenode::RuleNode, angelic_conditions::Dict{UInt16,UInt8})

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

"""
    clear_holes!(program::RuleNode, angelic_conditions::Dict{UInt16,UInt8})

Removes all subexpressions that are holes in the program, based on the angelic conditions. Modifies the program in-place.

# Arguments
- `program`: The program to remove holes from. Goes recursively through children.
- `angelic_conditions`: A dictionary mapping indices of angelic condition candidates, to the child index that may be changed.

"""
function clear_holes!(program::RuleNode, angelic_conditions::Dict{UInt16,UInt8})
    if haskey(angelic_conditions, program.ind)
        idx = angelic_conditions[program.ind]
        if program.children[idx] isa AbstractHole
            deleteat!(program.children, angelic_conditions[program.index])
        end
        for ch in program.children
            clear_holes!(ch, angelic_conditions)
        end
    end
end