"""
    Performs iterative library learning (Aulile) by enumerating programs using a grammar and synthesizing programs that 
        minimize the auxiliary scoring function across `IOExample`s.

    - `iter_t`: Type of program iterator to use (must be constructible with grammar and symbol).
    - `grammar`: The grammar used to generate candidate programs.
    - `start_symbol`: The non-terminal symbol representing the start of the grammar.
    - `new_rules_symbol`: A symbol used to add new rules to the grammar as library learning.

    Returns an `AulileStats` struct with the best program found, its score, number of iterations and enumerations.
"""
function aulile(
    iter_t::Type{<:ProgramIterator},
    grammar::AbstractGrammar,
    start_symbol::Symbol,
    new_rules_symbol::Symbol,
    options::AulileOptions
)::AulileStats
    evaluateOptions = options.synthOptions.evaluateOptions
    iter = iter_t(grammar, start_symbol, max_depth=options.max_depth)
    iter_state = nothing
    best_program = nothing
    
    # Get initial distance of input and output
    best_score = evaluateOptions.aux.initial_score(evaluateOptions.problem)
    if options.print_debug
        println("Initial Distance: $(best_score)")
    end
    init_grammar_size = length(grammar.rules)
    # Main loop
    new_rules_decoding = Dict{Int,AbstractRuleNode}()
    old_grammar_size = length(grammar.rules)
    total_enumerations = 0
    i = 0
    while i < options.max_iterations
        stats = synth_with_aux(iter, grammar, new_rules_decoding, best_score,
            options.synthOptions, iter_state)
        iter_state = stats.iter_state
        total_enumerations += stats.enumerations
        # Best program is from previous iterations
        if length(stats.programs) == 0
            # Reset iterator if exhausted
            if stats.exhausted_start
                iter_state = nothing
                iter = iter_t(grammar, start_symbol, max_depth=options.max_depth)
            else
                return AulileStats(best_program, best_score, i, total_enumerations)
            end
        else
            i += 1
            if best_score > 0
                @assert stats.score < best_score
            else
                # In the case where the distance is optimal from the start
                @assert stats.score <= best_score
            end
            best_program = stats.programs[1]
            best_score = stats.score
            # Program is optimal
            if best_score <= evaluateOptions.aux.best_value
                return AulileStats(best_program, best_score, i, total_enumerations)
            else
                for j in 1:length(stats.programs)
                    program = stats.programs[j]
                    program_expr = rulenode2expr(program, grammar)
                    add_rule!(grammar, :($new_rules_symbol = $program_expr))
                    if length(grammar.rules) > old_grammar_size
                        old_grammar_size = length(grammar.rules)
                        new_rules_decoding[old_grammar_size] = deepcopy(program)
                    end
                end
            end
            if options.print_debug
                println("Grammar after step $(i):")
                print_new_grammar_rules(grammar, init_grammar_size)
            end
        end
    end
    return AulileStats(best_program, best_score, max_iterations, total_enumerations)
end

"""
    Searches for the best program that minimizes the score defined by the auxiliary function.

    - `iterator`: Program enumeration iterator.
    - `grammar`: Grammar used to generate and interpret programs.
    - `new_rules_decoding`: A dictionary mapping rule indices to their original `RuleNode`s, 
        used when interpreting newly added grammar rules.
    - `score_upper_bound`: Current best score to beat.
    - `options`: A list of additional arguments.
    - `iter_state`: Optional iterator state to continue from.

    Returns a `SearchStats` object containing the best programs found (sorted best-first), 
    the iterator state, the best score, and the number of enumerations.
"""
function synth_with_aux(
    iterator::ProgramIterator,
    grammar::AbstractGrammar,
    new_rules_decoding::Dict{Int,AbstractRuleNode},
    score_upper_bound::Number,
    options::SynthOptions,
    iter_state=nothing,
)::SearchStats
    aux = options.evaluateOptions.aux
    ord = Base.Order.ReverseOrdering(Base.Order.By(t -> first(t)))
    best_programs = BinaryHeap{Tuple{Int,RuleNode}}(ord)
    worst_score = typemax(Int)
    iterator_exhausted_start = false

    start_time = time()
    loop_enumerations = 1
    for loop_enumerations in 1:options.max_enumerations
        if time() - start_time > options.max_time
            break
        end

        next_item = isnothing(iter_state) ? iterate(iterator) : iterate(iterator, iter_state)
        if isnothing(next_item)
            if options.print_debug
                println("Iterator exhausted.")
            end
            # Only track if the iterator was exhausted to begin with
            iterator_exhausted_start = loop_enumerations == 1
            break
        end

        candidate_program, iter_state = next_item
        score = evaluate_with_aux(candidate_program, grammar,
            new_rules_decoding, options.evaluateOptions)

        if score == aux.best_value
            candidate_program = freeze_state(candidate_program)
            if options.print_debug
                println("Found an optimal program!")
            end
            return SearchStats([candidate_program], iter_state, aux.best_value, 
                loop_enumerations, time() - start_time, false)
        elseif score < score_upper_bound
            candidate_program = freeze_state(candidate_program)
            if length(best_programs) < options.num_returned_programs
                push!(best_programs, (score, candidate_program))
                worst_score = first(first(best_programs))
            elseif score < worst_score
                pop!(best_programs)
                push!(best_programs, (score, candidate_program))
                worst_score = first(first(best_programs))
            end
        end
    end
    
    top_programs, best_found_score = heap_to_vec(best_programs)
    if length(top_programs) == 0 && options.print_debug
        println("Did not find a better program.")
    elseif options.print_debug
        println("Found a suboptimal program with distance: $(best_found_score)")
    end

    # The enumeration exhausted, but an optimal program was not found
    return SearchStats(top_programs, iter_state, best_found_score, 
        loop_enumerations, time() - start_time, iterator_exhausted_start)
end

"""
    Evaluates a candidate program over all examples in a problem using the auxiliary evaluation function.

    - `program`: The candidate program to evaluate.
    - `grammar`: Grammar used to generate and interpret programs.
    - `new_rules_decoding`: A dictionary mapping grammar rule indices to `RuleNode`s for decoding during interpretation.
    - `options`: A list of additional arguments.

    Returns the total distance score. If evaluation errors are disallowed and one occurs, an `EvaluationError` is thrown.
"""
function evaluate_with_aux(
    program::Any,
    grammar::AbstractGrammar,
    new_rules_decoding::Dict{Int,AbstractRuleNode},
    options::EvaluateOptions
)::Number
    distance_in_examples = 0
    crashed = false
    for example ∈ options.problem.spec
        try
            # Use the interpreter to get the output
            output = options.interpret(program, grammar, example, new_rules_decoding)
            distance_in_examples += options.aux(example, output)
        catch e
            # You could also decide to handle less severe errors (such as index out of range) differently,
            # for example by just increasing the error value and keeping the program as a candidate.
            crashed = true
            # Throw the error again if evaluation errors aren't allowed
            # eval_error = EvaluationError(expr, example.in, e)
            # allow_evaluation_errors || throw(eval_error)
            allow_evaluation_errors || throw(e)
            break
        end
    end
    if crashed
        return typemax(Int)
    else
        return distance_in_examples
    end
end