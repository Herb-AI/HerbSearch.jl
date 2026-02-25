"""
    Performs iterative library learning (Aulile) by enumerating programs using a grammar and synthesizing programs that 
        minimize the auxiliary scoring function across `IOExample`s.

    - `problem`: The problem definition with IO examples.
    - `iter_t`: Type of program iterator to use (must be constructible with grammar and symbol).
    - `grammar`: The grammar used to generate candidate programs.
    - `start_symbol`: The non-terminal symbol representing the start of the grammar.
    - `new_rules_decoding`: A dictionary to map new rules to interpretable ASTs during library learning.
    - `opts`: A list of additional arguments.

    Returns an `AulileStats` struct with the best program found, its score, and aulile metrics.
"""
function aulile(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iter_t::Type{<:ProgramIterator},
    grammar::AbstractGrammar;
    new_rules_decoding::Dict{Int,AbstractRuleNode}=Dict{Int,AbstractRuleNode}(),
    opts::AulileOptions=AulileOptions()
)::AulileStats
    aux = opts.synth_opts.eval_opts.aux
    best_score = aux.initial_score(problem)
    if opts.synth_opts.print_debug
        println("Initial Distance: $(best_score)")
    end

    iter = iter_t(grammar, opts.start_symbol, max_depth=opts.max_depth)
    checkpoint_program = nothing
    required_rules_before_checkpoint = Set{Int}()
    grammar_size = length(grammar.rules)

    best_program = nothing
    total_enums = 0
    for i in 1:opts.max_iterations
        stats = synth_with_aux(problem, iter, grammar, best_score;
            new_rules_decoding=new_rules_decoding,
            checkpoint_program=checkpoint_program,
            required_rules_before_checkpoint=required_rules_before_checkpoint,
            opts=opts.synth_opts)
        checkpoint_program = stats.last_program
        total_enums += stats.enumerations

        # Last iteration did not find better programs
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
        empty!(required_rules_before_checkpoint)
        compressed_programs = opts.compression(stats.programs, grammar; k=opts.synth_opts.num_returned_programs)
        for rule in compressed_programs
            rule_type = return_type(grammar, rule)
            new_expr = rulenode2expr(rule, grammar)
            to_add = :($rule_type = $(new_expr))
            if isprobabilistic(grammar)
                add_rule!(grammar, 1, to_add) # Adds small cost
            else
                add_rule!(grammar, to_add)
            end
            # Check if adding to the grammar was successful
            if length(grammar.rules) > grammar_size
                grammar_size = length(grammar.rules)
                new_rules_decoding[grammar_size] = rule
                push!(required_rules_before_checkpoint, grammar_size)
            end
        end

        if opts.synth_opts.print_debug
            println("Grammar after step $(i):")
            print_new_grammar_rules(grammar, grammar_size - opts.synth_opts.num_returned_programs)
        end

        iter = iter_t(grammar, opts.start_symbol, max_depth=opts.max_depth)
    end
    return AulileStats(best_program, best_score, opts.max_iterations, total_enums)
end

"""
    Searches for the best program that minimizes the score defined by the auxiliary function.

    - `problem`: The problem definition with IO examples.
    - `iterator`: Program enumeration iterator.
    - `grammar`: Grammar used to generate and interpret programs.
    - `score_upper_bound`: Current best score to beat.
    - `new_rules_decoding`: A dictionary to map new rules to interpretable ASTs during library learning.
    - `checkpoint_program`: Optional program used to disable the rule filter once reached.
    - `required_rules_before_checkpoint`: A set of grammar rule indices to be considered until checkpoint is reached.
    - `opts`: A list of additional arguments.

    Returns a `SearchStats` object containing the best programs found (sorted best-first), 
    the iterator state, and search metrics.
"""
function synth_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iterator::ProgramIterator,
    grammar::AbstractGrammar,
    score_upper_bound::Number;
    new_rules_decoding::Dict{Int,AbstractRuleNode}=Dict{Int,AbstractRuleNode}(),
    checkpoint_program::Union{AbstractRuleNode,Nothing}=nothing,
    required_rules_before_checkpoint::Set{Int}=Set{Int}(),
    opts::SynthOptions=SynthOptions(),
)::SearchStats
    aux_bestval = opts.eval_opts.aux.best_value
    # Max-heap to store minimal number of programs
    ord = Base.Order.ReverseOrdering(Base.Order.By(t -> first(t)))
    best_programs = BinaryHeap{Tuple{Int,RuleNode}}(ord)
    worst_score = typemax(Int)

    restoring_checkpoint = !isnothing(checkpoint_program) && opts.skip_old_programs
    checkpoint_constraint = restoring_checkpoint ? ContainsAny(collect(required_rules_before_checkpoint)) : nothing
    skipped_candidates = 0

    candidate_program = nothing
    start_time = time()
    loop_enums = 0
    for _candidate_program in iterator
        # Julia scoping issue - loop variables shadow outer ones
        candidate_program = _candidate_program
        # Skip old candidates until we reach checkpoint, from which point we search normally
        if restoring_checkpoint && !check_tree(checkpoint_constraint, candidate_program)
            skipped_candidates += 1
            continue
        elseif restoring_checkpoint && candidate_program == checkpoint_program
            restoring_checkpoint = false
            skipped_candidates += 1
            continue
        end

        loop_enums += 1
        score = evaluate_with_aux(problem, candidate_program, grammar, new_rules_decoding; opts=opts.eval_opts)
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

        if loop_enums >= opts.max_enumerations || time() - start_time > opts.max_time
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