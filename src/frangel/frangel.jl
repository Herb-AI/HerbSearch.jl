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
    iter::ProgramIterator
)
    remembered_programs = Dict{BitVector,Tuple{RuleNode,Int,Int}}()
    fragments = Set{RuleNode}()

    add_fragments_prob!(iter, config.generation.use_fragments_chance)

    state = nothing

    symboltable = SymbolTable(iter.grammar)
    start_time = time()

    while time() - start_time < iter.config.max_time
        # Generate random program
        program = state === nothing ? iterate(iter) : iterate(iter, state)
        # TODO: modify fragment

        passed_tests = BitVector([false for _ in iter.spec])
        # If it does not pass any tests, discard
        get_passed_tests!(program, iter.grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        if !any(passed_tests)
            continue
        end
        # Contains angelic condition
        if contains_hole(program)
            resolve_angelic!(program, fragments, passed_tests, iter.grammar, symboltable, spec, 1, angelic_conditions, config)
            # Still contains angelic conditions -> unresolved
            if contains_hole(program)
                continue
            end
            get_passed_tests!(program, iter.grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        end
        program = simplify_quick(program, iter.grammar, spec, passed_tests)
        get_passed_tests!(program, iter.grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        fragments = remember_programs!(remembered_programs, passed_tests, program, fragments, iter.grammar)
        if all(passed_tests)
            return program # simplify_slow(program), state
        end
    end
end