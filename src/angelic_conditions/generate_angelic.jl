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
    replacement_funcs::Vector{Function},
    angelic_conditions::Dict{UInt16,UInt8},
    config::FrAngelConfig,
    fragment_base_rules_offset::Int16,
    rule_minsize::AbstractVector{UInt8},
    symbol_minsize::Dict{Symbol,UInt8}
)::RuleNode
    num_holes = number_of_holes(program)
    # Try each replacement strategy
    for replacement_strategy in replacement_funcs
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
                changed = replacement_strategy(program, boolean_expr, config.angelic.angelic_rulenode, angelic_conditions)
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