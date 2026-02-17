"""
    Performs iterative library learning (Aulile) by enumerating programs using a grammar and synthesizing programs that 
        minimize the auxiliary scoring function across `IOExample`s.

    - `problem`: The problem definition with IO examples.
    - `iter_t`: Type of program iterator to use (must be constructible with grammar and symbol).
    - `grammar`: The grammar used to generate candidate programs.
    - `start_symbol`: The non-terminal symbol representing the start of the grammar.
    - `new_rules_symbol`: A symbol used to add new rules to the grammar as library learning.
    - `opts`: A list of additional arguments

    Returns an `AulileStats` struct with the best program found, its score, and aulile metrics.
"""
function aulile(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iter_t::Type{<:ProgramIterator},
    grammar::AbstractGrammar,
    start_symbol::Symbol;
    opts::AulileOptions=AulileOptions()
)::AulileStats
    SMALL_COST = 1
    aux = opts.synth_opts.eval_opts.aux
    best_score = aux.initial_score(problem)
    if opts.synth_opts.print_debug
        println("Initial Distance: $(best_score)")
    end

    iter = iter_t(grammar, start_symbol, max_depth=opts.max_depth)
    iter_state = nothing
    new_rules_decoding = Dict{Int,AbstractRuleNode}()
    grammar_size = length(grammar.rules)

    best_program = nothing
    total_enums = 0
    for i in 1:opts.max_iterations
        stats = synth_with_aux(problem, iter, grammar, new_rules_decoding, best_score;
            opts=opts.synth_opts, iter_state=iter_state)
        iter_state = stats.iter_state
        total_enums += stats.enumerations

        if length(stats.programs) == 0
            return AulileStats(best_program, best_score, i, total_enums)
        else
            # Iteration must improve the score
            @assert stats.score <= best_score
            best_score = stats.score

            best_program = stats.programs[1]
            if best_score <= aux.best_value
                # Program is optimal
                return AulileStats(best_program, best_score, i, total_enums)
            else
                compressed_programs = opts.compression(stats.programs, grammar; k=opts.synth_opts.num_returned_programs)
                # wrapped compression returns ::Vector{Vector{Expr}}. Each of those expressions needs to be added to the grammar.
                # the 1st expresison in each list must have a small nonzero cost, other expressions must have a cost of 0.
                for (i, new_rule) in enumerate(compressed_programs)
                    add_rule!(grammar, new_rule)
                    new_rules_decoding[length(grammar.rules)] = expr2rulenode(grammar.rules[end], grammar)
                    grammar_size = length(grammar.rules)
                end
            end
            if opts.synth_opts.print_debug
                println("Grammar after step $(i):")
                print_new_grammar_rules(grammar, grammar_size - opts.synth_opts.num_returned_programs)
            end
        end

        if opts.restart_iterator
            iter = iter_t(grammar, start_symbol, max_depth=opts.max_depth)
            iter_state = nothing
        end
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
    - `iter_state`: Optional iterator state to continue from.

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
    iter_state=nothing,
)::SearchStats
    aux_bestval = opts.eval_opts.aux.best_value
    # Max-heap to store minimal number of programs
    ord = Base.Order.ReverseOrdering(Base.Order.By(t -> first(t)))
    best_programs = BinaryHeap{Tuple{Int,RuleNode}}(ord)
    worst_score = typemax(Int)

    start_time = time()
    loop_enums = 1
    for loop_enums in 1:opts.max_enumerations
        if time() - start_time > opts.max_time
            break
        end

        next_item = isnothing(iter_state) ? iterate(iterator) : iterate(iterator, iter_state)
        if isnothing(next_item)
            if opts.print_debug
                println("Iterator exhausted.")
            end
            break
        end

        candidate_program, iter_state = next_item
        score = evaluate_with_aux(problem, candidate_program, grammar, new_rules_decoding;
            opts=opts.eval_opts)

        if score == aux_bestval
            # Optimal program
            candidate_program = freeze_state(candidate_program)
            if opts.print_debug
                println("Found an optimal program!")
            end
            return SearchStats([candidate_program], iter_state, aux_bestval, loop_enums, time() - start_time)
        elseif score >= score_upper_bound
            # Worse program that is not worth considering
            continue
        elseif length(best_programs) < opts.num_returned_programs || score < worst_score
            candidate_program = freeze_state(candidate_program)
            push!(best_programs, (score, candidate_program))
            length(best_programs) > opts.num_returned_programs && pop!(best_programs)
            worst_score = first(first(best_programs))
        end
    end
    top_programs, best_found_score = heap_to_vec(best_programs)
    if length(top_programs) == 0 && opts.print_debug
        println("Did not find a better program.")
    elseif opts.print_debug
        println("Found a suboptimal program with distance: $(best_found_score)")
    end
    # The enumerations are exhausted, but an optimal program was not found
    return SearchStats(top_programs, iter_state, best_found_score, loop_enums, time() - start_time)
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