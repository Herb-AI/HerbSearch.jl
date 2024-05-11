@kwdef struct FrAngelConfigGeneration
    max_size::Int = 40
    use_fragments_chance::Float16 = 0.5
    use_entire_fragment_chance::Float16 = 0.5
    use_angelic_conditions_chance::Float16 = 0.5
    similar_new_extra_size::Int = 8
    gen_similar_prob_new::Float16 = 0.25
end

@kwdef struct FrAngelConfigAngelic
    max_time::Float16 = 0.1
    boolean_expr_max_size::Int = 6
    max_execute_attempts::Int = 55
    max_allowed_fails::Float16 = 0.3
end

@kwdef struct FrAngelConfig
    max_time::Float16 = 5
    generation::FrAngelConfigGeneration = FrAngelConfigGeneration()
    angelic::FrAngelConfigAngelic = FrAngelConfigAngelic()
end

@programiterator FrAngelIterator(
    spec::AbstractVector{<:IOExample},
    config::FrAngelConfig,
    angelic_conditions::AbstractVector{Union{Nothing,Int}}
)

mutable struct FrAngelIteratorState
    remembered_programs::Dict{BitVector,Tuple{RuleNode,Int,Int}}
    fragments::Set{RuleNode}
end

function Base.iterate(iter::FrAngelIterator)
    iterate(iter, FrAngelIteratorState(
        Dict{BitVector,Tuple{RuleNode,Int,Int}}(),
        Set{RuleNode}()
    ))
end

function Base.iterate(iter::FrAngelIterator, state::FrAngelIteratorState)
    symboltable = SymbolTable(iter.grammar)
    start_time = time()
    while time() - start_time < iter.config.max_time
        # Generate random program
        program = generate_random_program(
            iter.grammar,
            iter.sym,
            state.fragments,
            iter.config.generation,
            iter.config.generation.use_angelic_conditions_chance,
            iter.angelic_conditions,
            iter.config.generation.max_size
        )
        passed_tests = BitVector([false for _ in iter.spec])
        # If it does not pass any tests, discard
        get_passed_tests!(program, iter.grammar, symboltable, iter.spec, passed_tests, iter.angelic_conditions, iter.config.angelic)
        if !any(passed_tests)
            continue
        end
        # Contains angelic condition
        if contains_hole(program)
            resolve_angelic!(program, state.fragments, passed_tests, iter.grammar, symboltable, iter.spec, 1, iter.angelic_conditions, iter.config)
            # Still contains angelic conditions -> unresolved
            if contains_hole(program)
                continue
            end
            get_passed_tests!(program, iter.grammar, symboltable, iter.spec, passed_tests, iter.angelic_conditions, iter.config.angelic)
        end
        program = simplify_quick(program, iter.grammar, iter.spec, passed_tests)
        get_passed_tests!(program, iter.grammar, symboltable, iter.spec, passed_tests, iter.angelic_conditions, iter.config.angelic)
        state.fragments = remember_programs!(state.remembered_programs, passed_tests, program, state.fragments, iter.grammar)
        if all(passed_tests)
            return program, state # simplify_slow(program), state
        end
        # i += 1
    end
end