"""
    resolve_angelic!(program::RuleNode, fragments::Set{RuleNode}, passing_tests::BitVector, grammar::AbstractGrammar, symboltable::SymbolTable, 
        tests::AbstractVector{<:IOExample}, replacement_dir::Int, angelic_conditions::AbstractVector{Union{Nothing,Int}}, config::FrAngelConfig)::RuleNode

Resolve angelic values in the given program by generating random boolean expressions and replacing the holes in the expression.

# Arguments
- `program`: The program to resolve angelic conditions in.
- `fragments`: A set of rule nodes representing the fragments of the program.
- `passing_tests`: A BitVector representing the tests that the program has already passed.
- `grammar`: The grammar rules of the program.
- `symboltable`: A symbol table for the grammar.
- `tests`: A vector of `IOExample` objects representing the input-output test cases.
- `replacement_dir`: The direction of replacement; 1 for top-down, -1 for bottom-up.
- `angelic_conditions`: A vector of integers representing the index of the child to replace, and the condition's type, with an angelic condition for each rule. 
    If there is no angelic condition for a rule, the value is set to `nothing`.
- `config`: The configuration object for FrAngel.

# Returns
The resolved program with angelic values replaced, or an unresolved program if it times out.

"""
function resolve_angelic!(
    program::RuleNode,
    fragments::Set{RuleNode},
    passing_tests::BitVector,
    grammar::AbstractGrammar,
    symboltable::SymbolTable,
    tests::AbstractVector{<:IOExample},
    replacement_dir::Int, # Direction of replacement; 1 -> top-down, -1 -> bottom-up
    angelic_conditions::AbstractVector{Union{Nothing,Int}},
    config::FrAngelConfig
)::RuleNode
    num_holes = number_of_holes(program)
    # Which hole to be replaced; if top-down -> first one; else -> last one
    replacement_index = replacement_dir == 1 || (num_holes - 1)
    angelic = config.angelic
    new_tests = BitVector([false for _ in tests])
    while num_holes != 0
        success = false
        start_time = time()
        while time() - start_time < max_time
            boolean_expr = generate_random_program(grammar, :Bool, fragments, config.generation, false, Vector{Union{Nothing,Int}}(), angelic.boolean_expr_max_size)
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
            return resolve_angelic!(program, fragments, passing_tests, grammar, symboltable, tests, -1, angelic_conditions, angelic)
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
    queue = [new_program]
    while !isempty(queue)
        node = dequeue!(queue)
        for (child_index, child) in enumerate(node.children)
            if node isa AbstractHole
                if replacement_index == 1
                    node.children[child_index] = boolean_expr
                    return program
                else
                    replacement_index -= 1
                end
            end
            enqueue!(queue, child)
        end
    end
    program
end

"""
    execute_angelic_on_input(symboltable::SymbolTable, program::RuleNode, grammar::AbstractGrammar, input::Dict{Symbol,Any}, 
        expected_output::Any, max_attempts::Int, angelic_conditions::AbstractVector{Union{Nothing,Int}})::Bool

Run test case `input` on `program` containing angelic conditions. This is done by optimistically evaluating the program, by generating different code paths
    and checking if any of them make the program pass the test case.

# Arguments
- `symboltable`: The symbol table containing the program's symbols.
- `program`: The program to be executed.
- `grammar`: The grammar rules of the program.
- `input`: A dictionary where each key is a symbol used in the expression, and the value is the corresponding value to be used in the expression's evaluation.
- `expected_output`: The expected output of the program.
- `max_attempts`: The maximum number of attempts before assuming the angelic program cannot be resolved.
- `angelic_conditions`: A vector of integers representing the index of the child to replace, and the condition's type, with an angelic condition for each rule. 
    If there is no angelic condition for a rule, the value is set to `nothing`.

# Returns
Whether the output of running `program` on `input` matches `output` within `max_attempts` attempts.

"""
function execute_angelic_on_input(
    symboltable::SymbolTable,
    program::RuleNode,
    grammar::AbstractGrammar,
    input::Dict{Symbol,Any},
    expected_output::Any,
    max_attempts::Int,
    angelic_conditions::AbstractVector{Union{Nothing,Int}}
)::Bool
    num_true, attempts = 0, 0
    symboltable[:update_✝γ_path] = update_✝γ_path
    # We check traversed code paths by prefix -> trie is efficient for this
    visited = DataStructures.Trie{Bool}()
    expr = create_angelic_expression(program, grammar, angelic_conditions)
    while num_true < max_attempts
        code_paths = Vector{Vector{Char}}()
        get_code_paths!(num_true, "", visited, code_paths, max_attempts - attempts)
        for code_path in code_paths
            # Create actual_code_path here to keep reference for simpler access later
            actual_code_path = Vector{Char}()
            # The angelic expression is the same as original, but with two "global" variables for code path control
            angelic_expr = quote
                ✝γ_actual_code_path = $actual_code_path
                ✝γ_code_path = $code_path
                $expr
            end
            try
                output = execute_on_input(symboltable, angelic_expr, input)
                if output == expected_output
                    return true
                end
            finally
                visited[String(actual_path)] = true
                attempts += 1
            end
        end
        num_true += 1
    end
    false
end

"""
    get_code_paths!(num_true::Int, curr::Vector{Char}, visited::DataStructures.Trie{Bool}, code_paths::Vector{String}, max_length::Int)

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
    curr::Vector{Char},
    visited::DataStructures.Trie{Bool},
    code_paths::Vector{String},
    max_length::Int
)
    str_curr = String(curr)
    if (length(curr) >= max_length || any(v -> v.is_key, partial_path(visited, str_curr)))
        return
    end
    if num_true == 0
        push!(code_paths, curr)
        return
    end
    push!(curr, '1')
    get_code_paths!(num_true - 1, curr, visited, code_paths, max_length)
    curr[length(curr)] = '0'
    get_code_paths!(num_true, curr, visited, code_paths, max_length)
    pop!(curr)
end

"""
    create_angelic_expression(program::RuleNode, grammar::AbstractGrammar, angelic_conditions::AbstractVector{Union{Nothing,Int}})

Create an angelic expression that can be ran, while also keeping track of the code path.

# Arguments
- `program`: The program to turn into an angelic expression.
- `grammar`: The grammar rules of the program.
- `angelic_conditions`: A vector of integers representing the index of the child to replace, and the condition's type, with an angelic condition for each rule. 
    If there is no angelic condition for a rule, the value is set to `nothing`.

# Returns
The generated angelic expression.

"""
function create_angelic_expression(
    program::RuleNode,
    grammar::AbstractGrammar,
    angelic_conditions::AbstractVector{Union{Nothing,Int}}
)::Expr
    new_program = deepcopy(program)
    angelic_grammar = deepcopy(grammar)
    for child_index in angelic_conditions
        if child_index !== nothing
            angelic_grammar.rules[rule_index][child_index] = :(update_✝γ_path(✝γ_code_path, ✝γ_actual_code_path))
        end
    end
    clear_holes!(new_program, angelic_conditions)
    rulenode2expr(new_program, angelic_grammar)
end

"""
    clear_holes!(program::RuleNode, angelic_conditions::AbstractVector{Union{Nothing,Int}})

Removes all subexpressions that are holes in the program, based on the angelic conditions. Modifies the program in-place.

# Arguments
- `program`: The program to remove holes from. Goes recursively through children.
- `angelic_conditions`: A vector of integers representing the index of the child to replace, and the condition's type, with an angelic condition for each rule. 
    If there is no angelic condition for a rule, the value is set to `nothing`.

"""
function clear_holes!(program::RuleNode, angelic_conditions::AbstractVector{Union{Nothing,Int}})
    if angelic_conditions[program.index] !== nothing
        idx = angelic_conditions[program.index]
        if program.children[idx] isa AbstractHole
            deleteat!(program.children, angelic_conditions[program.index])
        end
        for ch in program.children
            clear_holes!(ch, angelic_conditions)
        end
    end
end


"""
    update_✝γ_path(✝γ_code_path::Vector{Char}, ✝γ_actual_code_path::Vector{Char})

The injected function call that goes into where previously were the holes/angelic conditions. It updates the actual path taken during angelic evaluation.

# Arguments
- `✝γ_code_path`: The `attempted` code path. Values are removed until empty.
- `✝γ_actual_code_path`: The actual code path - Values from `✝γ_code_path` are appended until it is empty, then only the `false` path is taken.

# Returns
The next path to be taken in this control statement - either the first value of `✝γ_code_path`, or `false`.

"""
function update_✝γ_path(✝γ_code_path::Vector{Char}, ✝γ_actual_code_path::Vector{Char})::Bool
    # If attempted flow already completed - append `false` until return
    if length(✝γ_code_path) == 0
        push!(✝γ_actual_code_path, '0')
        return false
    end
    # Else take next and append to actual path
    res = ✝γ_code_path[1]
    popfirst!(✝γ_code_path)
    push!(✝γ_actual_code_path, res)
    res == '1'
end