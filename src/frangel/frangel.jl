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

@programiterator FrAngelIterator(
    spec::AbstractVector{<:IOExample},
    config::FrAngelConfig,
    angelic_conditions::AbstractVector{Union{Nothing,Int}}
)

"""
    mutable struct FrAngelIteratorState

A mutable struct representing the state of the FrAngel iterator.

# Fields
- `remembered_programs::Dict{BitVector,Tuple{RuleNode,Int,Int}}`: The currently stored programs, representing the best found programs so far. 
    It uses a dictionary mapping `passed_tests` to (program's tree, the tree's `node_count`, `program_length`).
- `fragments::Set{RuleNode}`: The currently stored fragments, used for generation of complex programs.

"""
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