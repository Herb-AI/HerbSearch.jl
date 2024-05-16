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
    fragments = Vector{RuleNode}() # TODO: change it to vector everywhere

    rule_minsize = rules_minsize(grammar) 
    for rule_index in eachindex(grammar.rules)
        sym = grammar.types[rule_index]
    
        if isterminal(grammar, rule_index) && grammar.rules[rule_index] == Symbol(string(:Fragment_, sym))
            rule_minsize[rule_index] = typemax(Int)
        end
    end

    symbol_minsize = symbols_minsize(grammar, rule_minsize)

    add_fragments_prob!(iter, config.generation.use_fragments_chance)

    fragments_offset = length(grammar.rules)

    state = nothing

    symboltable = SymbolTable(iter.grammar)
    start_time = time()

    while time() - start_time < iter.config.max_time
        # Generate random program
        program = state === nothing ? iterate(iter) : iterate(iter, state)

        modify_and_replace_program_fragments!(program, fragments, fragments_offset, config, iter.grammar, rule_minsize, symbol_minsize)
        # TODO: add angelic conditions?

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

function modify_and_replace_program_fragments!(
    program::RuleNode, 
    fragments::AbstractVector{RuleNode}, 
    fragments_offset::Number, 
    config::FrAngelConfigGeneration,
    grammar::AbstractGrammar, 
    rule_minsize::AbstractVector{Int},
    symbol_minsize::Dict{Symbol,Int}
)::RuleNode 
    if is_fragment_rule(grammar, program.ind)
        fragment_rule_index = program.children[1].ind
        # a fragment was found

        if rand() < config.use_entire_fragment_chance
            # use fragment as is
            return fragments[fragment_rule_index - fragments_offset]
        else
            # modify the fragment
            modified_fragment = deepcopy(fragments[fragment_rule_index - fragments_offset])
            random_modify_children!(grammar, modified_fragment, config, fragments_offset, rule_minsize, symbol_minsize)
            return modified_fragment
        end
    else
        # traverse the tree to find fragments to replace
        if isterminal(grammar, program.ind)
            return program
        end

        for (index, child) in enumerate(program.children)
            program.children[index] = modify_and_replace_program_fragments!(child, fragments, fragments_offset, config, grammar, rule_minsize, symbol_minsize)
        end

        program
    end
end

function random_modify_children!(
    grammar::AbstractGrammar,
    node::RuleNode,
    config::FrAngelConfigGeneration,
    fragments_offset::Number,
    rule_minsize::AbstractVector{Int},
    symbol_minsize::Dict{Symbol,Int}
)::Nothing
    for (index, child) in enumerate(node.children)
        if rand() < config.gen_similar_prob_new
            node.children[index] = generate_random_program(grammar, return_type(grammar, child), config, fragments_offset, count_nodes(grammar, child) + config.similar_new_extra_size, rule_minsize, symbol_minsize)
        else
            random_modify_children!(grammar, child, config, fragments_offset, rule_minsize, symbol_minsize)
        end
    end
end

function generate_random_program(
    grammar::AbstractGrammar,
    type::Symbol,
    config::FrAngelConfigGeneration,
    fragments_offset::Number,
    max_size,
    rule_minsize::AbstractVector{Int},
    symbol_minsize::Dict{Symbol,Int}
)::Union{RuleNode,Nothing}
    if max_size < 0
        return nothing
    end
   
    possible_rules = filter(r -> rule_minsize[r] ≤ max_size && r <= fragments_offset, grammar[type])
    if isempty(possible_rules)
        return nothing
    end
    rule_index = StatsBase.sample(possible_rules)
    rule_node = RuleNode(rule_index)

    if !grammar.isterminal[rule_index]
        sizes = random_partition(grammar, rule_index, max_size, symbol_minsize)

        for (index, child_type) in enumerate(child_types(grammar, rule_index))
            push!(rule_node.children, generate_random_program(grammar, child_type, config, fragments_offset, sizes[index], rule_minsize, symbol_minsize))
        end
    end

    rule_node
end