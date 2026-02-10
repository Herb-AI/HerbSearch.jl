"""
    aulile(problem::Problem, iter_t::Type{<:ProgramIterator}, grammar::AbstractGrammar, start_symbol::Symbol, 
        new_rules_symbol::Symbol, aux::AuxFunction; interpret=default_interpreter, allow_evaluation_errors=false,
        max_iterations=10000, programs_per_iteration=1, max_depth=10, max_enumerations=100000, print_debug=false) 
            -> AulileStats

    Performs iterative library learning (Aulile) by enumerating programs using a grammar and synthesizing programs that 
        minimize the auxiliary scoring function across `IOExample`s.

    - `problem`: A `Problem` object containing a list of `IOExample`s.
    - `iter_t`: Type of program iterator to use (must be constructible with grammar and symbol).
    - `grammar`: The grammar used to generate candidate programs.
    - `start_symbol`: The non-terminal symbol representing the start of the grammar.
    - `new_rules_symbol`: A symbol used to add new rules to the grammar as library learning.
    - `aux`: An `AuxFunction` that defines the evaluation metric and desired score.
    - `interpret`: An interpret function for the grammar.
    - `allow_evaluation_errors`: Whether to allow evaluation errors (such as in the grammar).
    - `max_iterations`: Maximum number of learning iterations to perform.
    - `programs_per_iteration`: Number of best programs stored in grammar per iteration. 
    - `max_depth`: Maximum depth for program enumeration.
    - `max_enumerations`: Maximum number of candidate programs to try per iteration.
    - `print_debug`: Whether to print debug info.

    Returns an `AulileStats` struct with the best program found, its score, number of iterations and enumerations.
"""
function aulile(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iter_t::Type{<:ProgramIterator},
    grammar::AbstractGrammar,
    start_symbol::Symbol,
    new_rules_symbol::Symbol,
    aux::AuxFunction;
    interpret::Function=default_interpreter,
    allow_evaluation_errors::Bool=false,
    max_iterations=5,
    programs_per_iteration=1,
    max_depth=10,
    max_enumerations=100000,
    print_debug=false,
)::AulileStats
    iter = iter_t(grammar, start_symbol, max_depth=max_depth)
    iter_state = nothing
    best_program = nothing
    # Get initial distance of input and output
    best_score = aux.initial_score(problem)
    if print_debug
        println("Initial Distance: $(best_score)")
    end
    init_grammar_size = length(grammar.rules)
    # Main loop
    new_rules_decoding = Dict{Int,AbstractRuleNode}()
    old_grammar_size = length(grammar.rules)
    total_enumerations = 0
    i = 0
    while i < max_iterations
        # Run synth
        stats = synth_with_aux(problem, iter, grammar, aux,
            new_rules_decoding, best_score,
            interpret=interpret, iter_state=iter_state,
            allow_evaluation_errors=allow_evaluation_errors,
            num_returned_programs=programs_per_iteration,
            max_enumerations=max_enumerations, print_debug=print_debug)
        iter_state = stats.iter_state
        total_enumerations += stats.enumerations
        # Best program is from previous iterations
        if length(stats.programs) == 0
            # Reset iterator if exhausted
            if stats.exhausted_start
                iter_state = nothing
                iter = iter_t(grammar, start_symbol, max_depth=max_depth)
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
            if best_score <= aux.best_value
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
            if print_debug
                println("Grammar after step $(i):")
                print_new_grammar_rules(grammar, init_grammar_size)
            end
        end
    end
    return AulileStats(best_program, best_score, max_iterations, total_enumerations)
end

"""
    synth_with_aux(problem::Problem, iterator::ProgramIterator, grammar::AbstractGrammar, 
        aux::AuxFunction, new_rules_decoding::Dict{Int, AbstractRuleNode}, best_score::Number;
        interpret=default_interpreter, iter_state=nothing, allow_evaluation_errors=false, 
        max_time=typemax(Int), max_enumerations=typemax(Int), print_debug=false) -> SearchStats

    Searches for the best program that minimizes the score defined by the auxiliary function.

    - `problem`: The problem definition with IO examples.
    - `iterator`: Program enumeration iterator.
    - `grammar`: Grammar used to generate and interpret programs.
    - `aux`: An `AuxFunction` used to compute the score between program output and expected output.
    - `new_rules_decoding`: A dictionary mapping rule indices to their original `RuleNode`s, 
        used when interpreting newly added grammar rules.
    - `best_score`: Current best score to beat.
    - `interpret`: Interpreter function for the grammar (defaults to `default_interpreter`).
    - `iter_state`: Optional iterator state to continue from.
    - `allow_evaluation_errors`: Whether to tolerate runtime exceptions during evaluation.
    - `num_returned_programs`: Number of best programs returned. 
    - `max_time`: Maximum allowed runtime for the synthesis loop.
    - `max_enumerations`: Maximum number of candidate programs to try.
    - `print_debug`: If true, print debug output.

    Returns a `SearchStats` object containing the best programs found (sorted best-first), 
    the iterator state, the best score, and the number of enumerations.
"""
function synth_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iterator::ProgramIterator,
    grammar::AbstractGrammar,
    aux::AuxFunction,
    new_rules_decoding::Dict{Int,AbstractRuleNode},
    best_score::Number;
    interpret::Function=default_interpreter,
    iter_state=nothing,
    allow_evaluation_errors::Bool=false,
    num_returned_programs=1,
    max_time=typemax(Int),
    max_enumerations=typemax(Int),
    print_debug=false
)::SearchStats
    start_time = time()
    loop_enumerations = 0

    ord = Base.Order.ReverseOrdering(Base.Order.By(t -> first(t)))
    best_programs = BinaryHeap{Tuple{Int,RuleNode}}(ord)
    worst_score = typemax(Int)
    iterator_exhausted_start = false

    while true
        next_item = isnothing(iter_state) ? iterate(iterator) : iterate(iterator, iter_state)
        if isnothing(next_item)
            if print_debug
                println("Iterator exhausted.")
            end
            # Only track if the iterator was exhausted to begin with
            if loop_enumerations == 0
                iterator_exhausted_start = true
            end
            break
        end
        candidate_program, iter_state = next_item
        loop_enumerations += 1
        # Evaluate the program
        score = evaluate_with_aux(problem, candidate_program, grammar, aux,
            new_rules_decoding, interpret=interpret,
            allow_evaluation_errors=allow_evaluation_errors)
        # Update score if better
        if score == aux.best_value
            candidate_program = freeze_state(candidate_program)
            if print_debug
                println("Found an optimal program!")
            end
            return SearchStats([candidate_program], iter_state, aux.best_value, loop_enumerations, false)
        elseif score < best_score
            candidate_program = freeze_state(candidate_program)
            if length(best_programs) < num_returned_programs
                push!(best_programs, (score, candidate_program))
                worst_score = first(first(best_programs))
            elseif score < worst_score
                pop!(best_programs)
                push!(best_programs, (score, candidate_program))
                worst_score = first(first(best_programs))
            end
        end
        # Check stopping criteria
        if loop_enumerations >= max_enumerations || time() - start_time > max_time
            break
        end
    end
    # Turn max heap into a list (best-to-worst order)
    top_programs = Vector{RuleNode}()
    best_found_score = best_score
    while !isempty(best_programs)
        score, program = pop!(best_programs)
        push!(top_programs, program)
        best_found_score = score
    end
    reverse!(top_programs)
    # Debug
    if length(top_programs) == 0 && print_debug
        println("Did not find a better program.")
    elseif print_debug
        println("Found a suboptimal program with distance: $(best_found_score)")
    end
    # The enumeration exhausted, but an optimal program was not found
    return SearchStats(top_programs, iter_state, best_found_score, loop_enumerations, iterator_exhausted_start)
end

"""
    evaluate_with_aux(problem::Problem, program::Any, grammar::AbstractGrammar, aux::AuxFunction,
        new_rules_decoding::Dict{Int, AbstractRuleNode}; interpret=default_interpreter, 
        allow_evaluation_errors=false) -> Number

    Evaluates a candidate program over all examples in a problem using the auxiliary evaluation function.

    - `problem`: The problem definition with IO examples.
    - `program`: The candidate program to evaluate.
    - `grammar`: Grammar used to generate and interpret programs.
    - `aux`: An `AuxFunction` used to compute the score between expected and actual output.
    - `new_rules_decoding`: A dictionary mapping grammar rule indices to `RuleNode`s for decoding during interpretation.
    - `interpret`: Interpreter function for program evaluation (defaults to `default_interpreter`).
    - `allow_evaluation_errors`: Whether evaluation errors should be tolerated or raise an exception.

    Returns the total distance score. If evaluation errors are disallowed and one occurs, an `EvaluationError` is thrown.
"""
function evaluate_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    program::Any,
    grammar::AbstractGrammar,
    aux::AuxFunction,
    new_rules_decoding::Dict{Int,AbstractRuleNode};
    interpret::Function=default_interpreter,
    allow_evaluation_errors::Bool=false
)::Number
    distance_in_examples = 0
    crashed = false
    for example ∈ problem.spec
        try
            # Use the interpreter to get the output
            output = interpret(program, grammar, example, new_rules_decoding)
            distance_in_examples += aux(example, output)
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