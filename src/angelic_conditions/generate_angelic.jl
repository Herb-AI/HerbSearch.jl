"""
    resolve_angelic!(
        program::RuleNode, passing_tests::BitVector, grammar::AbstractGrammar, symboltable::SymbolTable, tests::AbstractVector{<:IOExample}, 
        replacement_func::Function, angelic_conditions::Dict{UInt16,UInt8}, angelic_config::ConfigAngelic, evaluation_grammar::AbstractGrammar)::RuleNode

Resolve angelic conditions in the given program by generating random boolean expressions and replacing the holes in the expression.
The program is modified in-place. All replacement strategies are attempted sequentially as provided.

# Arguments
- `program`: The program to resolve angelic conditions in.
- `passing_tests`: A BitVector representing the tests that the program has already passed.
- `grammar`: The grammar rules of the program to be used for sampling angelic condition candidates.
- `symboltable`: A symbol table for the grammar.
- `tests`: A vector of `IOExample` objects representing the input-output test cases.
- `replacement_func`: The function to use for replacement -> either `replace_first_angelic!` or `replace_last_angelic!`.
- `angelic_conditions`: A dictionary mapping indices of angelic condition candidates, to the child index that may be changed.
- `angelic_config`: The configuration for angelic conditions.
- `evaluation_grammar`: The grammar rules of the program to be used for evaluation. Usually the same as `grammar`, or augmented with fragments.

# Returns
The resolved program with angelic values replaced, or an unresolved program if it times out.

"""
function resolve_angelic!(
    program::RuleNode,
    passing_tests::BitVector,
    grammar::AbstractGrammar,
    symboltable::SymbolTable,
    tests::AbstractVector{<:IOExample},
    replacement_funcs::Vector{Function},
    angelic_conditions::Dict{UInt16,UInt8},
    angelic_config::ConfigAngelic,
    evaluation_grammar::AbstractGrammar=grammar
)::RuleNode
    num_holes = number_of_holes(program)
    # Try each replacement strategy
    for replacement_strategy in replacement_funcs
        new_tests = BitVector([false for _ in tests])
        # Continue resolution until all holes are filled
        while num_holes != 0
            success = false
            start_time = time()
            # Keep track of visited replacements - avoid duplicates
            visited = init_long_hash_map()
            while time() - start_time < angelic_config.max_time
                # Generate a replacement
                boolean_expr = rand(RuleNode, grammar, :Bool, angelic_config.boolean_expr_max_depth)
                program_hash = hash(boolean_expr)
                if lhm_contains(visited, program_hash)
                    continue
                end
                lhm_put!(visited, program_hash)
                # Either replace 'first' or 'last' hole
                changed = replacement_strategy(program, boolean_expr, angelic_config.angelic_rulenode, angelic_conditions)
                update_passed_tests!(program, evaluation_grammar, symboltable, tests, new_tests, angelic_conditions, angelic_config)
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
            if success
                num_holes -= 1
            else
                break
            end
        end
    end
    return program
end

"""
    add_angelic_conditions!(program::RuleNode, grammar::AbstractGrammar, angelic_conditions::Dict{UInt16,UInt8})::RuleNode

Add angelic conditions to a program. This is done by replacing some of the nodes indicated by `angelic_conditions`` with holes.

# Arguments
- `program`: The program to modify.
- `grammar`: The grammar rules of the program.
- `angelic_conditions`: A dictionary mapping indices of angelic condition candidates, to the child index that may be changed.

# Returns
The modified program with angelic conditions added.

"""
function add_angelic_conditions!(program::RuleNode, grammar::AbstractGrammar, angelic_conditions::Dict{UInt16,UInt8})::RuleNode
    if isterminal(grammar, program.ind)
        return program
    end
    # If the current node has an angelic child, look for it
    if haskey(angelic_conditions, program.ind)
        angelic_condition_ind = angelic_conditions[program.ind]
        for (index, child) in enumerate(program.children)
            # Traverse children for angelic condition candidates
            if index != angelic_condition_ind
                program.children[index] = add_angelic_conditions!(child, grammar, angelic_conditions)
                # A hole represents the angelic condition's location - to be replaced by angelic rulenode before evaluation
            else
                program.children[index] = Hole(grammar.domains[grammar.childtypes[program.ind][angelic_condition_ind]])
            end
        end
        # Traverse the node's children for angelic condition candidates
    else
        for (index, child) in enumerate(program.children)
            program.children[index] = add_angelic_conditions!(child, grammar, angelic_conditions)
        end
    end
    program
end