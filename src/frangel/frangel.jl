"""
    struct FrAngelConfigGeneration

A configuration struct for FrAngel generation.

# Fields
- `max_size::Int`: The maximum size of the generated program.
- `use_fragments_chance::Float16`: The chance of using fragments during generation.
- `use_entire_fragment_chance::Float16`: The chance of using the entire fragment during replacement over modifying a program's children.
- `use_angelic_conditions_chance::Float16`: The chance of using angelic conditions during generation.
- `similar_new_extra_size::Int`: The extra size allowed for newly generated children during replacement.
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
- `max_time::Float16`: The maximum time allowed for resolving angelic conditions.
- `boolean_expr_max_size::Int`: The maximum size of boolean expressions when resolving angelic conditions.
- `max_execute_attempts::Int`: The maximal attempts of executing the program with angelic evaluation.
- `max_allowed_fails::Float16`: The maximum allowed fraction of failed tests during evaluation before short-circuit failure.

"""
@kwdef mutable struct FrAngelConfigAngelic
    max_time::Float16 = 0.1
    boolean_expr_max_size::UInt8 = 6
    max_execute_attempts::Int = 55
    max_allowed_fails::Float16 = 0.75
    truthy_tree::Union{Nothing,RuleNode} = nothing
end

"""
    struct FrAngelConfig

The full configuration struct for FrAngel. Includes generation and angelic sub-configurations.

# Fields
- `max_time::Float16`: The maximum time allowed for execution of whole iterator.
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
    remembered_programs = Dict{BitVector,Tuple{RuleNode,Int,Int}}()
    fragments = Vector{RuleNode}()
    grammar = iter.grammar
    fragment_base_rules_offset::Int16 = length(grammar.rules)
    add_fragment_base_rules!(grammar)
    fragment_rules_offset::Int16 = length(grammar.rules)
    resize!(rule_minsize, fragment_rules_offset)
    for i in fragment_base_rules_offset+1:fragment_rules_offset
        rule_minsize[i] = 255
    end
    symboltable = SymbolTable(grammar)

    add_fragments_prob!(grammar, config.generation.use_fragments_chance, fragment_base_rules_offset, fragment_rules_offset)

    state = nothing
    visited = Set{RuleNode}()
    start_time = time()
    verbose_level = config.verbose_level

    if isnothing(config.angelic.truthy_tree) && config.generation.use_angelic_conditions_chance != 0
        res = false
        truthy_tree = nothing
        while !res
            truthy_tree = generate_random_program(grammar, :Bool, config.generation, fragment_base_rules_offset, config.angelic.boolean_expr_max_size, rule_minsize, symbol_minsize)
            try
                res = execute_on_input(symboltable, rulenode2expr(truthy_tree, grammar), spec[1].in)
            catch
                res = false
            end
        end
        config.angelic.truthy_tree = truthy_tree
    end

    if verbose_level > 0
        println("Grammar:")
        print_grammar(grammar)
        println("Minimal sizes per rule: ", rule_minsize)
        println("Minimal size per symbol: ", symbol_minsize)
    end

    iterationCount, checkedProgram = 0, 0
    while time() - start_time < config.max_time
        iterationCount += 1
        # Generate random program
        program, state = (state === nothing) ? iterate(iter) : iterate(iter, state)

        if checkedProgram < verbose_level
            println("==== Iteration #", iterationCount, " ====")
            println(program)
        end

        # Generalize these two procedures at some point
        program = modify_and_replace_program_fragments!(program, fragments, fragment_base_rules_offset, fragment_rules_offset, config.generation, grammar, rule_minsize, symbol_minsize)
        if config.generation.use_angelic_conditions_chance != 0
            program = add_angelic_conditions!(program, grammar, angelic_conditions, config.generation)
        end

        # Do not check visited program space
        if program in visited
            continue
        end
        push!(visited, program)

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

        if config.generation.use_fragments_chance != 0
            # Update grammar with fragments
            if !config.compare_programs_by_length
                program_expr = nothing
            end
            fragments, updatedFragments = remember_programs!(remembered_programs, passed_tests, program, program_expr, fragments, grammar)
            if checkedProgram <= verbose_level
                println("---- Fragments ----")
                for f in fragments
                    println(f)
                end
                println("--------------------")
            end
            if updatedFragments
                # Remove old fragments from grammar (by resetting to base grammar) / remove all rules aftere fragment_rules_offset
                for i in reverse(fragment_rules_offset+1:length(grammar.rules))
                    remove_rule!(grammar, i)
                end
                cleanup_removed_rules!(grammar)
                # Add fragments to grammar
                add_fragment_rules!(grammar, fragments)
                add_fragments_prob!(grammar, config.generation.use_fragments_chance, fragment_base_rules_offset, fragment_rules_offset)
                # Update rule_minsize and symbol_minsize        
                for i in fragment_base_rules_offset+1:fragment_rules_offset
                    symbol_minsize[grammar.rules[i]] = 255
                end
                resize!(rule_minsize, length(grammar.rules))
                for i in fragment_base_rules_offset+1:fragment_rules_offset
                    symbol_minsize[grammar.rules[i]] = 255
                end

                for (i, fragment) in enumerate(fragments)
                    rule_minsize[fragment_rules_offset+i] = count_nodes(grammar, fragment)
                    ret_typ = return_type(grammar, fragment_rules_offset + i)
                    if haskey(symbol_minsize, ret_typ)
                        symbol_minsize[ret_typ] = min(symbol_minsize[ret_typ], rule_minsize[fragment_rules_offset+i])
                    else
                        symbol_minsize[ret_typ] = rule_minsize[fragment_rules_offset+i]
                    end
                end
                for i in fragment_base_rules_offset+1:fragment_rules_offset
                    if !isterminal(grammar, i)
                        rule_minsize[i] = symbol_minsize[grammar.rules[i]]
                    else
                        rule_minsize[i] = 255
                    end
                end
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