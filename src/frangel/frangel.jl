"""
    struct FrAngelConfigGeneration

A configuration struct for FrAngel generation.

# Fields
- `max_size::Int`: The maximum size of the generated program.
- `use_fragments_chance::Float16`: The chance of using fragments during generation.
- `use_entire_fragment_chance::Float16`: The chance of using the entire fragment during replacement over modifying a program's children.
- `use_angelic_conditions_chance::Float16`: The chance of using angelic conditions during generation.
- `new_children_max_depth::Int64`: The extra size allowed for newly generated children during replacement.
- `gen_similar_prob_new::Float16`: The chance of generating a new child / replacing a node randomly. 

"""
@kwdef struct FrAngelConfigGeneration
    max_size::Int = 40
    use_fragments_chance::Float16 = 0.5
    use_entire_fragment_chance::Float16 = 0.5
    use_angelic_conditions_chance::Float16 = 0.5
    new_children_max_depth::Int64 = 2
    gen_similar_prob_new::Float16 = 0.25
end

"""
    struct FrAngelConfig

The full configuration struct for FrAngel. Includes generation and angelic sub-configurations.

# Fields
- `max_time::Float16`: The maximum time allowed for execution of whole iterator.
- `try_to_simplify::Bool`: Whether to try to simplify the program before mining fragments.
- `compare_programs_by_length::Bool`: Whether to compare programs by length if they have same number of AST nodes.
- `generation::FrAngelConfigGeneration`: The generation configuration for FrAngel.
- `angelic::ConfigAngelic`: The configuration for angelic conditions of FrAngel.

"""
@kwdef struct FrAngelConfig
    max_time::Float16 = 5
    try_to_simplify::Bool = false
    compare_programs_by_length::Bool = false
    generation::FrAngelConfigGeneration = FrAngelConfigGeneration()
    angelic::ConfigAngelic = ConfigAngelic()
end

"""
    frangel(
        spec::AbstractVector{<:IOExample}, config::FrAngelConfig, angelic_conditions::Dict{UInt16,UInt8}, 
        iter::ProgramIterator, rule_minsize::AbstractVector{UInt8}, symbol_minsize::Dict{Symbol,UInt8})::RuleNode

The main function for FrAngel. It generates a program that passes all the given examples, or times out if one was not found.

# Arguments
- `spec`: The examples to pass.
- `config`: The configuration for FrAngel. It contains as sub-configurations the generation and angelic conditions configurations.
- `angelic_conditions`: A dictionary mapping indices of angelic condition candidates, to the child index that may be changed.
- `iter`: The iterator to use for generating programs.
- `rule_minsize`: A vector of minimum sizes for each production rule in the grammar. Can be obtained from [`rules_minsize`](@ref).
- `symbol_minsize`: A dictionary with the minimum size achievable for each symbol in the grammar. Can be obtained from [`symbols_minsize`](@ref).

# Description

FrAngel is a component-based program synthesizer that makes use of two main features, fragments and angelic conditions, to address the aspects of exploitation and exploration respectively.
https://arxiv.org/pdf/1811.05175
The function changes the grammar in every iteration, by adding fragments as rulenodes accessible to the iterator. For example, the following grammar:
```julia
    Num = |(0:10)
    Num = (Num + Num) | (Num - Num) | x
    Bool = (Num == Num) | (Num < Num)
```
will be changed at initialization to:
```julia
    Num = |(0:10)
    Num = (Num + Num) | (Num - Num) | x
    Bool = (Num == Num) | (Num < Num)
    Num = Fragment_Num
    Bool = Fragment_Bool
```
, and in a given iteration with fragments [(5 + x), (x == 3)], it will be changed to:
```julia
    Num = |(0:10)
    Num = (Num + Num) | (Num - Num) | x
    Bool = (Num == Num) | (Num < Num)
    Num = Fragment_Num
    Bool = Fragment_Bool
    Fragment_Num = (5 + x) | 5 | x | 3
    Fragment_Bool = (x == 3)
```.

It also turns it into a probabilistic grammar, based on the configuration (how often to use fragments).

The `rule_minsize` and `symbol_minsize` arguments are not strictly required. To abide by the FrAngel spec, the function operates on a `RuleNode` nodesize- instead of depth-basis.
With an iterator that does not use nodesize, these two arrays will not be used.

# Notes
- `spec` must be a non-empty vector of [`IOExample`](@ref).	
- Terminals in the grammar cannot be angelic conditions (it is faulty conceptually, as well).
- The ideal order of the grammar rules is to group rules with the same return type/LHS together, and sorted with terminals on top, 
    and recursive rules (rules that contain the return type itself) at the end. While this is not a strict requirement, the program may crash otherwise.
- `iter` must use a bottom-up search procedure. Since the grammar is changed in every iteration, top-down iterators need to be regenerated in every iteration, wrecking performance.

"""
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
    fragments = Vector{RuleNode}()
    grammar = iter.solver.grammar
    base_grammar = deepcopy(grammar)
    symboltable = SymbolTable(grammar)
    replacement_strategy = [replace_first_angelic!, replace_last_angelic!]
    state = nothing
    start_time = time()

    # Add angelic rule and save index if not provided
    if isnothing(config.angelic.angelic_rulenode)
        add_rule!(grammar, :(Angelic = update_✝_angelic_path))
        config.angelic.angelic_rulenode = RuleNode(length(grammar.rules))
    end

    # Setup grammar with fragments
    (fragment_base_rules_offset, fragment_rules_offset) = setup_grammar_with_fragments!(grammar, config.generation.use_fragments_chance)
    # Resize rule_minsize
    ############################################
    #### REMOVE ONCE RANDOMSTATEITERATOR IS USED
    ############################################
    resize!(rule_minsize, fragment_rules_offset)
    for i in fragment_base_rules_offset+1:fragment_rules_offset
        rule_minsize[i] = 255
    end
    ############################################

    # Main loop
    while time() - start_time < config.max_time
        # Generate random program
        program, state = (state === nothing) ? iterate(iter) : iterate(iter, state)

        use_angelic = config.generation.use_angelic_conditions_chance != 0 && rand() < config.generation.use_angelic_conditions_chance
        # Modify the program with fragments
        program = modify_and_replace_program_fragments!(program, fragments, fragment_base_rules_offset, fragment_rules_offset, config.generation,
            base_grammar, use_angelic)
        # Modify the program with angelic conditions
        if use_angelic
            program = add_angelic_conditions!(program, grammar, angelic_conditions)
        end

        passed_tests = BitVector([false for _ in spec])
        # If it does not pass any tests, discard
        program_expr = update_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        if !any(passed_tests)
            continue
        end

        # If it contains angelic conditions, resolve them
        if contains_hole(program)
            program = resolve_angelic!(program, passed_tests, base_grammar, symboltable, spec, replacement_strategy, angelic_conditions, config.angelic, grammar)
            # Still contains angelic conditions -> unresolved
            if contains_hole(program)
                continue
            end
            program_expr = update_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        end

        # Simplify and rerun over examples
        if config.try_to_simplify
            program = simplify_quick(program, grammar, spec, passed_tests, fragment_base_rules_offset)
            program_expr = update_passed_tests!(program, grammar, symboltable, spec, passed_tests, angelic_conditions, config.angelic)
        end

        # Early return -> if it passes all tests, then final round of simplification and return
        if all(passed_tests)
            return simplify_quick(program, grammar, spec, passed_tests, fragment_base_rules_offset)
        end

        # Update remember programs and fragments
        if config.generation.use_fragments_chance != 0
            fragments, updatedFragments = remember_programs!(remembered_programs, passed_tests, program,
                (!config.compare_programs_by_length ? nothing : program_expr), fragments, grammar)
            # Only run if there is a change in remembered programs
            if updatedFragments
                updateGrammarWithFragments!(grammar, fragments, fragment_base_rules_offset, fragment_rules_offset, config.generation.use_fragments_chance)
                # Update minimal sizes
                ############################################
                #### REMOVE ONCE RANDOMSTATEITERATOR IS USED
                ############################################
                update_min_sizes!(grammar, fragment_base_rules_offset, fragment_rules_offset, fragments, rule_minsize, symbol_minsize)
                ############################################
            end
        end
    end
end