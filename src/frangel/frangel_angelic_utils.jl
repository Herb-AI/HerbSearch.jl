"""
    resolve_angelic!(program::RuleNode, fragments::Set{RuleNode}, passing_tests::BitVector, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, 
        max_time::Float16, boolean_expr_max_size::Int, replacement_dir::Int, angelic_max_execute_attempts::Int, 
        angelic_conditions::AbstractVector{Union{Nothing,Int}}, angelic_max_allowed_fails::Float16)::RuleNode

Resolve angelic values in the given program by generating random boolean expressions and replacing the angelic holes.

# Arguments
- `program`: The program to resolve angelic values in.
- `fragments`: A set of rule nodes representing the fragments of the program.
- `passing_tests`: A bit vector indicating which tests the program passes.
- `grammar`: The grammar used to generate random boolean expressions.
- `tests`: An abstract vector of IOExample objects representing the tests.
- `max_time`: The maximum time allowed for resolving angelic values.
- `boolean_expr_max_size`: The maximum size of the generated boolean expressions.
- `replacement_dir`: The direction of replacement; 1 for top-down, -1 for bottom-up.
- `angelic_max_execute_attempts`: An integer representing the maximum number of attempts to execute the program with angelic evaluation.
- `angelic_conditions`: A vector of integers representing the index of the child to replace, and the condition's type, with an angelic condition for each rule. If there is no angelic condition for a rule, the value is set to `nothing`.
- `angelic_max_allowed_fails`: The maximum allowed fraction of failed tests.

# Returns
The resolved program with angelic values replaced, or an unresoled program if it times out.
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
- `program`: The root node of the program.
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

function execute_angelic_on_input(
    symboltable::SymbolTable,
    program::RuleNode,
    grammar::AbstractGrammar,
    input::Dict{Symbol,Any},
    expected_output::Any,
    max_attempts::Int,
    angelic_conditions::AbstractVector{Union{Nothing,Int}}
)::Any
    num_true, attempts = 0, 0
    symboltable[:update_✝γ_path] = update_✝γ_path
    visited = DataStructures.Trie{Bool}()
    expr = create_angelic_expression(program, grammar, angelic_conditions)
    while num_true < max_attempts
        code_paths = Vector{Vector{Char}}()
        get_code_paths!(num_true, "", visited, code_paths, max_attempts - attempts)
        for code_path in code_paths
            actual_code_path = Vector{Char}()
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

function get_code_paths!(
    num_true::Int,
    curr::Vector{Char},
    visited::DataStructures.Trie{Bool},
    code_paths::Vector{String},
    max_attempts::Int
)
    str_curr = String(curr)
    if (length(curr) >= max_attempts || any(v -> v.is_key, partial_path(visited, str_curr)))
        return
    end
    if num_true == 0
        push!(code_paths, curr)
        return
    end
    push!(curr, '1')
    get_code_paths!(num_true - 1, curr, visited, code_paths, max_attempts)
    curr[length(curr)] = '0'
    get_code_paths!(num_true, curr, visited, code_paths, max_attempts)
    pop!(curr)
end

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