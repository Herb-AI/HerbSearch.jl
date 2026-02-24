const SMALL_COST = 1

"""
    Performs iterative library learning (Aulile) by enumerating programs using a grammar and synthesizing programs that 
        minimize the auxiliary scoring function across `IOExample`s.

    - `problem`: The problem definition with IO examples.
    - `iter_t`: Type of program iterator to use (must be constructible with grammar and symbol).
    - `grammar`: The grammar used to generate candidate programs.
    - `start_symbol`: The non-terminal symbol representing the start of the grammar.
    - `new_rules_symbol`: A symbol used to add new rules to the grammar as library learning.
    - `opts`: A list of additional arguments.

    Returns an `AulileStats` struct with the best program found, its score, and aulile metrics.
"""
function aulile(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iter_t::Type{<:ProgramIterator},
    grammar::AbstractGrammar,
    start_symbol::Symbol;
    opts::AulileOptions=AulileOptions()
)::AulileStats
    aux = opts.synth_opts.eval_opts.aux
    best_score = aux.initial_score(problem)
    if opts.synth_opts.print_debug
        println("Initial Distance: $(best_score)")
    end

    iter = iter_t(grammar, start_symbol, max_depth=opts.max_depth)
    required_constraint = nothing
    checkpoint_program = nothing
    new_rules_decoding = Dict{Int,AbstractRuleNode}()
    grammar_size = length(grammar.rules)

    best_program = nothing
    total_enums = 0
    for i in 1:opts.max_iterations
        new_rules_indices = Set{Int}()
        stats = synth_with_aux(problem, iter, grammar, new_rules_decoding, best_score;
            opts=opts.synth_opts,
            required_constraint=required_constraint,
            checkpoint_program=checkpoint_program)
        checkpoint_program = stats.last_program
        total_enums += stats.enumerations

        if length(stats.programs) == 0
            return AulileStats(best_program, best_score, i, total_enums)
        end

        # Iteration must improve the score
        @assert stats.score <= best_score
        best_score = stats.score

        best_program = stats.programs[1]
        if best_score <= aux.best_value
            # Program is optimal
            return AulileStats(best_program, best_score, i, total_enums)
        end

        # Update grammar with the new compressed programs
        new_rules_indices = Set{Int}()
        compressed_programs = opts.compression(stats.programs, grammar; k=opts.synth_opts.num_returned_programs)
        for rule in compress_programs
            rule_type = return_type(grammar, rule)
            new_expr = rulenode2expr(rule, grammar)
            to_add = :($rule_type = $(new_expr))
            if isprobabilistic(grammar)
                add_rule!(grammar, SMALL_COST, to_add)
            else
                add_rule!(grammar, to_add)
            end
            if length(grammar.rules) > grammar_size
                grammar_size = length(grammar.rules)
                new_rules_decoding[grammar_size] = rule
            end
        end
        push!(new_rules_indices, grammar_size)
    
        if opts.synth_opts.print_debug
            println("Grammar after step $(i):")
            print_new_grammar_rules(grammar, grammar_size - opts.synth_opts.num_returned_programs)
        end

        required_constraint = opts.synth_opts.count_previously_seen_programs && 
            !isempty(new_rules_indices) ? ContainsAny(collect(new_rules_indices)) : nothing
        if opts.synth_opts.print_debug && !isnothing(required_constraint)
            println("ContainsAny constraint will be checked: $(required_constraint.rules)")
        end
        iter = iter_t(grammar, start_symbol, max_depth=opts.max_depth)
    end
    return AulileStats(best_program, best_score, max_iterations, total_enums)
end

"""
    Searches for the best program that minimizes the score defined by the auxiliary function.

    - `problem`: The problem definition with IO examples.
    - `iterator`: Program enumeration iterator.
    - `grammar`: Grammar used to generate and interpret programs.
    - `new_rules_decoding`: A dictionary mapping rule indices to their original `RuleNode`s, 
        used when interpreting newly added grammar rules.
    - `score_upper_bound`: Current best score to beat.
    - `opts`: A list of additional arguments.
    - `required_constraint`: Optional `ContainsAny` constraint; when provided, candidates must satisfy it.
    - `checkpoint_program`: Optional program used to disable the rule filter once reached.

    Returns a `SearchStats` object containing the best programs found (sorted best-first), 
    the iterator state, and search metrics.
"""
function synth_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iterator::ProgramIterator,
    grammar::AbstractGrammar,
    new_rules_decoding::Dict{Int,AbstractRuleNode},
    score_upper_bound::Number;
    opts::SynthOptions=SynthOptions(),
    required_constraint::Union{Nothing,ContainsAny}=nothing,
    checkpoint_program::Union{Nothing,AbstractRuleNode}=nothing,
)::SearchStats
    aux_bestval = opts.eval_opts.aux.best_value
    # Max-heap to store minimal number of programs
    ord = Base.Order.ReverseOrdering(Base.Order.By(t -> first(t)))
    best_programs = BinaryHeap{Tuple{Int,RuleNode}}(ord)
    worst_score = typemax(Int)

    candidate_program = nothing
    restoring_checkpoint = !isnothing(required_constraint)
    skipped_candidates = 0

    start_time = time()
    loop_enums = 0
    for (loop_enums, candidate_program) in enumerate(iterator)
        # Skip checked candidates if restoring to a checkpoint
        if restoring_checkpoint
            if candidate_program == checkpoint_program
                restoring_checkpoint = false
                continue
            elseif !check_tree(required_constraint, candidate_program)
                skipped_candidates += 1
                continue
            end
        end

        score = evaluate_with_aux(problem, candidate_program, grammar, new_rules_decoding;
            opts=opts.eval_opts)
        if score == aux_bestval
            optimal_program = freeze_state(candidate_program)
            if opts.print_debug
                println("Found an optimal program!")
                if skipped_candidates > 0
                    println("Skipped candidates: $(skipped_candidates)")
                end
            end
            return SearchStats([optimal_program], optimal_program, aux_bestval, loop_enums, time() - start_time)
        elseif score >= score_upper_bound
            # Worse program that is not worth considering
            continue
        elseif length(best_programs) < opts.num_returned_programs || score < worst_score
            push!(best_programs, (score, freeze_state(candidate_program)))
            length(best_programs) > opts.num_returned_programs && pop!(best_programs)
            worst_score = first(first(best_programs))
        end

        if loop_enums > opts.max_enumerations || time() - start_time > opts.max_time
            break
        end
    end

    top_programs, best_found_score = heap_to_vec(best_programs)
    if opts.print_debug
        if length(top_programs) == 0
            println("Did not find a better program.")
        else
            println("Found a suboptimal program with distance: $(best_found_score)")
        end
        if skipped_candidates > 0
            println("Skipped candidates: $(skipped_candidates)")
        end
    end
    # The enumerations are exhausted, but an optimal program was not found
    return SearchStats(top_programs, candidate_program, best_found_score, loop_enums, time() - start_time)
end

"""
    Evaluates a candidate program over all examples in a problem using the auxiliary evaluation function.

    - `problem`: The problem definition with IO examples.
    - `program`: The candidate program to evaluate.
    - `grammar`: Grammar used to generate and interpret programs.
    - `new_rules_decoding`: A dictionary mapping grammar rule indices to `RuleNode`s for decoding during interpretation.
    - `opts`: A list of additional arguments.

    Returns the total distance score. If evaluation errors are disallowed and one occurs, an `EvaluationError` is thrown.
"""
function evaluate_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    program::AbstractRuleNode,
    grammar::AbstractGrammar,
    new_rules_decoding::Dict{Int,AbstractRuleNode};
    opts::EvaluateOptions=EvaluateOptions()
)::Number
    distance_in_examples = 0
    crashed = false
    for example ∈ problem.spec
        try
            # Use the interpreter to get the output
            output = opts.interpret(program, grammar, example, new_rules_decoding)
            distance_in_examples += opts.aux(example, output)
        catch e
            # You could also decide to handle less severe errors (such as index out of range) differently,
            # for example by just increasing the error value and keeping the program as a candidate.
            crashed = true
            # Throw the error again if evaluation errors aren't allowed
            eval_error = EvaluationError(rulenode2expr(program, grammar), example.in, e)
            opts.allow_evaluation_errors || throw(eval_error)
            break
        end
    end
    return crashed ? typemax(Int) : distance_in_examples
end