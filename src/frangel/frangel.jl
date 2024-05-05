@kwdef struct FrAngelConfig
    max_time::Float16 = 10
    angelic_max_time::Float16 = 0.1
    angelic_boolean_expr_max_size::Int = 6
    random_generation_max_size::Int = 40
    random_generation_use_fragments_chance::Float16 = 0.5
    use_angelic_conditions_chance::Float16 = 0.5
    angelic_max_execute_attempts::Int = 55
    similar_new_extra_size::Int = 8
    gen_similar_prob_new::Float16 = 0.25
    random_generation_use_entire_fragment_chance::Float16 = 0.5
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
    start_time = time()
    while time() - start_time < iter.config.max_time
        # Generate random program
        program = generate_random_program(
            iter.grammar,
            iter.sym,
            state.fragments,
            iter.config,
            iter.config.use_angelic_conditions_chance,
            iter.angelic_conditions,
            iter.config.random_generation_max_size
        )
        # If it does not pass any tests, discard
        passed_tests = get_passed_tests(program, iter.grammar, iter.spec, iter.config.angelic_max_execute_attempts)
        if !any(passed_tests)
            continue
        end
        # Contains angelic condition
        if contains_hole(program)
            resolve_angelic!(program, state.fragments, passed_tests, iter.grammar, iter.spec, iter.config.angelic_max_time, 
                iter.config.angelic_boolean_expr_max_size, 1, iter.config.angelic_max_execute_attempts)
            # Still contains angelic conditions -> unresolved
            if contains_hole(program)
                continue
            end
            passed_tests = get_passed_tests(program, iter.grammar, iter.spec, iter.config.angelic_max_execute_attempts)
        end
        program = simplify_quick(program, iter.grammar, iter.spec, passed_tests)
        passed_tests = get_passed_tests(program, iter.grammar, iter.spec, iter.config.angelic_max_execute_attempts)
        # Update iterator state (remembered programs and fragments)
        state.fragments = remember_programs!(state.remembered_programs, passed_tests, program, state.fragments, iter.grammar)
        if all(passed_tests)
            return program, state # simplify_slow(program), state
        end
    end
end