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
    use_fragments_chance::Float64 = 0.5
    use_entire_fragment_chance::Float16 = 0.5
    use_angelic_conditions_chance::Float16 = 0.5
    similar_new_extra_size::Int = 8
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
@kwdef struct FrAngelConfigAngelic
    max_time::Float16 = 0.1
    boolean_expr_max_size::Int = 6
    max_execute_attempts::Int = 55
    max_allowed_fails::Float16 = 0.3
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
    generation::FrAngelConfigGeneration = FrAngelConfigGeneration()
    angelic::FrAngelConfigAngelic = FrAngelConfigAngelic()
end

function frangel(
    spec::AbstractVector{<:IOExample},
    config::FrAngelConfig,
    angelic_conditions::AbstractVector{Union{Nothing,Int}},
    iter::ProgramIterator,
    rule_minsize::AbstractVector{UInt8},
    symbol_minsize::Dict{Symbol,UInt8}
)
    remembered_programs = Dict{BitVector,Tuple{RuleNode,Int,Int}}()
    fragments = Vector{RuleNode}()
    grammar = iter.grammar
    base_grammar = deepcopy(grammar)
    symboltable = SymbolTable(grammar)

    add_fragments_prob!(grammar, config.generation.use_fragments_chance)
    fragments_offset = length(grammar.rules)
    state = nothing

    fragment_base_rules::Vector{Tuple{Int, Symbol}} = collect(map(i -> (i, grammar.rules[i]), filter(i -> grammar.rules[i] == Symbol(string(:Fragment_, grammar.types[i])) , eachindex(grammar.rules))))

    visited = Set{RuleNode}()

    start_time = time()

    while time() - start_time < config.max_time
        # Generate random program
        program, state = (state === nothing) ? iterate(iter) : iterate(iter, state)

        # Generalize these two procedures at some point
        program = modify_and_replace_program_fragments!(program, fragments, fragments_offset, config.generation, grammar, rule_minsize, symbol_minsize)
        program = add_angelic_conditions!(program, grammar, angelic_conditions, config.generation)

        if program in visited
            continue
        end
        push!(visited, program)

        passed_tests = BitVector([false for _ in spec])
        # If it does not pass any tests, discard
        get_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        if !any(passed_tests)
            continue
        end
        # If it contains angelic conditions, resolve them
        if contains_hole(program)
            resolve_angelic!(program, fragments, passed_tests, grammar, symboltable, spec, 1, angelic_conditions, config)
            # Still contains angelic conditions -> unresolved
            if contains_hole(program)
                continue
            end
            get_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        end

        # Simplify and rerun over examples
        # TODO program = simplify_quick(program, grammar, spec, passed_tests)
        get_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)

        # Early return -> if it passes all tests, then final round of simplification and return
        if all(passed_tests)
            # TODO program = simplify_slow(program, grammar, spec, angelic_conditions, (time() - start_time) / 10)
            return simplify_quick(program, grammar, spec, passed_tests)
        end

        # Update grammar with fragments
        fragments, updatedFragments = remember_programs!(remembered_programs, passed_tests, program, fragments, grammar)
        if updatedFragments
            # Remove old fragments from grammar (by resetting to base grammar)
            grammar = deepcopy(base_grammar)
            # Add fragments to grammar
            add_rules!(grammar, fragments)
            add_fragments_prob!(grammar, config.generation.use_fragments_chance)
            # Update rule_minsize and symbol_minsize        
            resize!(rule_minsize, length(grammar.rules))
            for (i, fragment) in enumerate(fragments)
                rule_minsize[fragments_offset + i] = count_nodes(grammar, fragment)

                ret_typ = return_type(grammar, fragments_offset + i)
                if haskey(symbol_minsize, ret_typ)
                    symbol_minsize[ret_typ] = min(symbol_minsize[ret_typ], rule_minsize[fragments_offset + i])
                else 
                    symbol_minsize[ret_typ] = rule_minsize[fragments_offset + i]
                end
            end
            for (index, key) in fragment_base_rules
                rule_minsize[index] = symbol_minsize[key]
            end
        end
    end
end