"""
    struct FrAngelConfigGeneration

A configuration struct for FrAngel generation.

# Fields
- `max_size::Int`: The maximum size of the generated program.
- `use_fragments_chance::Float16`: The chance of using fragments during generation.
- `use_entire_fragment_chance::Float16`: The chance of using the entire fragment during replacement over modifying a program's children.
- `use_angelic_conditions_chance::Float16`: The chance of using angelic conditions during generation.
- `similar_new_extra_size::UInt8`: The extra size allowed for newly generated children during replacement.
- `gen_similar_prob_new::Float16`: The chance of generating a new child / replacing a node randomly. 

"""
@kwdef struct FrAngelConfigGeneration
    max_size::Int = 40
    use_fragments_chance::Float16 = 0.5
    use_entire_fragment_chance::Float16 = 0.5
    use_angelic_conditions_chance::Float16 = 0.5
    similar_new_extra_size::UInt8 = 8
    gen_similar_prob_new::Float16 = 0.25
end

"""
    struct FrAngelConfigAngelic

A configuration struct for the angelic mode of FrAngel.

# Fields
- `max_time::Float16`: The maximum time allowed for resolving a single angelic expression.
- `boolean_expr_max_size::Int`: The maximum size of boolean expressions when resolving angelic conditions.
- `max_execute_attempts::Int`: The maximal attempts of executing the program with angelic evaluation.
- `max_allowed_fails::Float16`: The maximum allowed fraction of failed tests during evaluation before short-circuit failure.
- `angelic_rulenode::Union{Nothing,RuleNode}`: The angelic rulenode. Used to replace angelic conditions/holes right before evaluation.

"""
@kwdef mutable struct FrAngelConfigAngelic
    max_time::Float16 = 0.1
    boolean_expr_max_size::UInt8 = 6
    max_execute_attempts::Int = 55
    max_allowed_fails::Float16 = 0.75
    angelic_rulenode::Union{Nothing,RuleNode} = nothing
end

"""
    struct FrAngelConfig

The full configuration struct for FrAngel. Includes generation and angelic sub-configurations.

# Fields
- `max_time::Float16`: The maximum time allowed for execution of whole iterator.
- `try_to_simplify::Bool`: Whether to try to simplify the program before mining fragments.
- `compare_programs_by_length::Bool`: Whether to compare programs by length if they have same number of AST nodes.
- `verbose_level::Int`: The verbosity level of the output. This will print the program and all intermediate steps for the first `verbose_level` checked programs.
- `generation::FrAngelConfigGeneration`: The generation configuration for FrAngel.
- `angelic::FrAngelConfigAngelic`: The configuration for angelic conditions of FrAngel.

"""
@kwdef struct FrAngelConfig
    max_time::Float16 = 5
    try_to_simplify::Bool = false
    compare_programs_by_length::Bool = false
    verbose_level::Int = 0
    generation::FrAngelConfigGeneration = FrAngelConfigGeneration()
    angelic::FrAngelConfigAngelic = FrAngelConfigAngelic()
end

function frangel(
    spec::AbstractVector{<:IOExample},
    config::FrAngelConfig,
    angelic_conditions::Dict{UInt16,UInt8},
    iter::ProgramIterator,
    rule_minsize::AbstractVector{UInt8},
    symbol_minsize::Dict{Symbol,UInt8}
)
    # Setup algorithm
    remembered_programs = Dict{BitVector,Tuple{RuleNode,Int,Int}}()
    visited = init_long_hash_map()
    fragments = Vector{RuleNode}()

    verbose_level = config.verbose_level
    grammar = iter.solver.grammar
    symboltable = SymbolTable(grammar)

    # Add angelic rule and save index if not provided
    if isnothing(config.angelic.angelic_rulenode)
        add_rule!(grammar, :(Angelic = update_✝_angelic_path))
        config.angelic.angelic_rulenode = RuleNode(length(grammar.rules))
    end

    # Setup grammar with fragments
    (fragment_base_rules_offset, fragment_rules_offset) = setup_grammar_with_fragments!(grammar, config.generation.use_fragments_chance, rule_minsize)
    state = nothing
    start_time = time()

    if verbose_level > 0
        println("Grammar:")
        print_grammar(grammar)
        println("Minimal sizes per rule: ", rule_minsize)
        println("Minimal size per symbol: ", symbol_minsize)
    end

    # Main loop
    iterationCount, checkedProgram = 0, 0
    while time() - start_time < config.max_time
        iterationCount += 1
        # Generate random program
        program, state = (state === nothing) ? iterate(iter) : iterate(iter, state)

        if checkedProgram < verbose_level
            println("==== Iteration #", iterationCount, " ====")
            println(program)
        end

        use_angelic = config.generation.use_angelic_conditions_chance != 0 && rand() < config.generation.use_angelic_conditions_chance

        # Modify the program with fragments
        program = modify_and_replace_program_fragments!(program, fragments, fragment_base_rules_offset, fragment_rules_offset, config.generation,
            grammar, rule_minsize, symbol_minsize, use_angelic)
        # Modify the program with angelic conditions
        if use_angelic
            program = add_angelic_conditions!(program, grammar, angelic_conditions)
        end

        # Do not check visited program space
        program_hash = hash(program)
        if lhm_contains(visited, program_hash)
            continue
        end
        lhm_put!(visited, program_hash)

        checkedProgram += 1
        if checkedProgram <= verbose_level
            println("Checked program #", checkedProgram)
            println(program)
            println(rulenode2expr(program, grammar))
        end

        passed_tests = BitVector([false for _ in spec])
        # If it does not pass any tests, discard
        program_expr = get_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        if !any(passed_tests)
            continue
        end

        # If it contains angelic conditions, resolve them
        if contains_hole(program)
            program = resolve_angelic!(program, passed_tests, grammar, symboltable, spec, 1, angelic_conditions, config, fragment_base_rules_offset, rule_minsize, symbol_minsize)
            # Still contains angelic conditions -> unresolved
            if contains_hole(program)
                continue
            end
            program_expr = get_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        end

        # Simplify and rerun over examples
        if config.try_to_simplify
            program = simplify_quick(program, grammar, spec, passed_tests, fragment_base_rules_offset)
            program_expr = get_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        end

        # Early return -> if it passes all tests, then final round of simplification and return
        if all(passed_tests)
            # TODO program = simplify_slow(program, grammar, spec, angelic_conditions, (time() - start_time) / 10)
            if verbose_level > 0
                println("Total iterations:", iterationCount)
                println("Checked programs:", checkedProgram)
            end
            return simplify_quick(program, grammar, spec, passed_tests, fragment_base_rules_offset)
        end

        # Update remember programs and fragments
        if config.generation.use_fragments_chance != 0
            fragments, updatedFragments = remember_programs!(remembered_programs, passed_tests, program, (!config.compare_programs_by_length ? nothing : program_expr), fragments, grammar)

            if checkedProgram <= verbose_level
                println("---- Fragments ----")
                for f in fragments
                    println(f)
                end
                println("--------------------")
            end

            # Only run if there is a change in remembered programs
            if updatedFragments
                # Remove old fragments from grammar (by removing fragment rules)
                for i in reverse(fragment_rules_offset+1:length(grammar.rules))
                    remove_rule!(grammar, i)
                end
                cleanup_removed_rules!(grammar)

                # Add new fragments to grammar and update probabilities
                add_fragment_rules!(grammar, fragments)
                add_fragments_prob!(grammar, config.generation.use_fragments_chance, fragment_base_rules_offset, fragment_rules_offset)

                # Update minimal sizes
                update_min_sizes!(grammar, fragment_base_rules_offset, fragment_rules_offset, fragments, rule_minsize, symbol_minsize)

                if checkedProgram <= verbose_level
                    println("Grammar:")
                    print_grammar(grammar)
                    println("Minimal sizes per rule: ", rule_minsize)
                    println("Minimal size per symbol: ", symbol_minsize)
                end
            end
        end
    end
    if verbose_level > 0
        println("Total iterations:", iterationCount)
        println("Checked programs:", checkedProgram)
    end
end