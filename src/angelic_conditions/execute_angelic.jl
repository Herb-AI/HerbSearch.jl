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
                if output == expected_output
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