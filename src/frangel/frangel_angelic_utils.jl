"""
    resolve_angelic!(program::RuleNode, fragments::Set{RuleNode}, passing_tests::BitVector, grammar::AbstractGrammar, tests::AbstractVector{<:IOExample}, 
        max_time::Float16, boolean_expr_max_size::Int, replacement_dir::Int, angelic_max_execute_attempts::Int)::RuleNode

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

# Returns
The resolved program with angelic values replaced, or an unresoled program if it times out.
"""
function resolve_angelic!(
    program::RuleNode,
    fragments::Set{RuleNode},
    passing_tests::BitVector,
    grammar::AbstractGrammar,
    tests::AbstractVector{<:IOExample},
    max_time::Float16,
    boolean_expr_max_size::Int,
    replacement_dir::Int, # Direction of replacement; 1 -> top-down, -1 -> bottom-up
    angelic_max_execute_attempts::Int
)::RuleNode
    num_holes = number_of_holes(program)
    # Which hole to be replaced; if top-down -> first one; else -> last one
    replacement_index = replacement_dir == 1 || (num_holes - 1)
    while num_holes != 0
        success = false
        start_time = time()
        while time() - start_time < max_time
            boolean_expr = generate_random_program(grammar, :Bool, fragments, config, false, boolean_expr_max_size)
            new_program = replace_next_angelic(program, boolean_expr, replacement_index)
            new_tests = get_passed_tests(new_program, grammar, tests, angelic_max_execute_attempts)
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
            return resolve_angelic!(program, fragments, passing_tests, grammar, tests, max_time, boolean_expr_max_size, -1, angelic_max_execute_attempts)
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