"""
	AuxFunction(func::Function, initial_score::Function, best_value::Number)

A wrapper struct for auxiliary evaluation functions used in the Aulile learning loop.

- `func`: A function that returns a score based on an `IOExample` and the candidate output.
- `initial_score`: A function that returns initial score based on `Problem`.
- `best_value`: The target score the synthesizer attempts to minimize. When a program achieves this score across all examples, 
    it is considered optimal.
"""
struct AuxFunction
    func::Function
    initial_score::Function
    best_value::Number # NOTE: Aulile tries to *minimize* to this value
end

"""
    SearchStats

Holds statistics about a search process.

# Fields
- `score`::Int: The score of the best program attained.
- `iterations::Int`: The number of iterations performed during the search.
- `enumerations::Int`: The number of enumerations performed during the search.
"""
struct SearchStats
    program::Union{RuleNode,Nothing}
    score::Int
    iterations::Int
    enumerations::Int
end

# Make `AuxFunction` behave like a regular callable function.
function (af::AuxFunction)(example::IOExample, output)
    return af.func(example, output)
end

"""
    default_interpreter(program::Any, grammar::AbstractGrammar, example::IOExample, _)

Default interpreter implementation that follows the execute_on_input pattern.
This is used when no custom interpreter is provided to synth_with_aux.
"""
function default_interpreter(program::Any, grammar::AbstractGrammar, example::IOExample, _)
    # Convert the program to an expression if it's a RuleNode
    expr = program isa AbstractRuleNode ? rulenode2expr(program, grammar) : program
    symboltable = grammar2symboltable(grammar)
    return execute_on_input(symboltable, expr, example.in)
end

"""
    Default auxiliary function of just checking how many tests are correct.
"""
default_aux = AuxFunction(
    (expected::IOExample{<:Any,<:Any}, actual::Any) -> begin
        if expected.out == actual
            return 0
        else
            return 1
        end
    end,
    problem::Problem -> length(problem.spec),
    0
)

"""
    print_new_grammar_rules(grammar::AbstractGrammar, init_grammar_size::Int)

Prints the new grammar rules added after a specific point in the grammar.

# Arguments
- `grammar::AbstractGrammar`: The grammar object containing rules and types.
- `init_grammar_size::Int`: The initial size of the grammar before new rules were added.
"""
function print_new_grammar_rules(grammar::AbstractGrammar, init_grammar_size::Int)
    println("{...}")
    for i in init_grammar_size+1:length(grammar.rules)
        println(i, ": ", grammar.types[i], " = ", grammar.rules[i])
    end
    println()
end

"""
    aulile(problem::Problem, iter_t::Type{<:ProgramIterator}, grammar::AbstractGrammar, start_symbol::Symbol, 
        new_rules_symbol::Symbol, aux::AuxFunction; interpret=default_interpreter, allow_evaluation_errors=false,
        max_iterations=10000, max_depth=10, max_enumerations=100000, print_debug=false) -> Union{Tuple{RuleNode, SynthResult}, Nothing}

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
- `max_depth`: Maximum depth for program enumeration.
- `max_enumerations`: Maximum number of candidate programs to try per iteration.
- `print_debug`: Whether to print debug info.

Returns a `SearchStats` struct with the best program found, its score, number of iterations and enumerations.
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
    max_iterations=10000,
    max_depth=10,
    max_enumerations=100000,
    print_debug=false,
)::SearchStats
    iter = iter_t(grammar, start_symbol, max_depth=max_depth)
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
    for i in 1:max_iterations
        stats = synth_with_aux(problem, iter, grammar, aux,
            new_rules_decoding, best_score,
            interpret=interpret, allow_evaluation_errors=allow_evaluation_errors,
            max_enumerations=max_enumerations, print_debug=print_debug)
        total_enumerations += stats.enumerations
        if stats.program isa Nothing
            return SearchStats(nothing, stats.score, i, total_enumerations)
        else
            if best_score > 0
                @assert stats.score < best_score
            else
                # In the case where the distance is optimal from the start
                @assert stats.score <= best_score
            end
            best_program = stats.program
            best_score = stats.score
            if best_score <= aux.best_value
                return SearchStats(stats.program, stats.score, i, total_enumerations)
            else
                program_expr = rulenode2expr(stats.program, grammar)
                add_rule!(grammar, :($new_rules_symbol = $program_expr))
                if length(grammar.rules) > old_grammar_size
                    old_grammar_size = length(grammar.rules)
                    new_rules_decoding[old_grammar_size] = deepcopy(stats.program)
                end
                iter = iter_t(grammar, start_symbol, max_depth=max_depth)
            end
            if print_debug
                println("Grammar after step $(i):")
                print_new_grammar_rules(grammar, max(init_grammar_size, length(grammar.rules) - 3))
            end
        end
    end
    return SearchStats(best_program, best_score, max_iterations, total_enumerations)
end

"""
    synth_with_aux(problem::Problem, iterator::ProgramIterator, grammar::AbstractGrammar, 
        aux::AuxFunction, new_rules_decoding::Dict{Int, AbstractRuleNode}, best_score::Int;
        interpret=default_interpreter, allow_evaluation_errors=false, max_time=typemax(Int), 
        max_enumerations=typemax(Int), print_debug=false) -> Union{Tuple{RuleNode, Int}, Nothing}

Searches for the best program that minimizes the score defined by the auxiliary function.

- `problem`: The problem definition with IO examples.
- `iterator`: Program enumeration iterator.
- `grammar`: Grammar used to generate and interpret programs.
- `aux`: An `AuxFunction` used to compute the score between program output and expected output.
- `new_rules_decoding`: A dictionary mapping rule indices to their original `RuleNode`s, 
    used when interpreting newly added grammar rules.
- `best_score`: Current best score to beat.
- `interpret`: Interpreter function for the grammar (defaults to `default_interpreter`).
- `allow_evaluation_errors`: Whether to tolerate runtime exceptions during evaluation.
- `max_time`: Maximum allowed runtime for the synthesis loop.
- `max_enumerations`: Maximum number of candidate programs to try.
- `print_debug`: If true, print debug output.

Returns a `SearchStats` object with the best program found (if any), its score, number of iterations and enumerations.
"""
function synth_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iterator::ProgramIterator,
    grammar::AbstractGrammar,
    aux::AuxFunction,
    new_rules_decoding::Dict{Int,AbstractRuleNode},
    best_score::Int;
    interpret::Function=default_interpreter,
    allow_evaluation_errors::Bool=false,
    max_time=typemax(Int),
    max_enumerations=typemax(Int),
    print_debug=false
)::SearchStats
    start_time = time()
    best_program = nothing
    loop_enumerations = 0
    for (loop_enumerations, candidate_program) ∈ enumerate(iterator)
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
            return SearchStats(candidate_program, aux.best_value, 1, loop_enumerations)
        elseif score < best_score
            best_score = score
            candidate_program = freeze_state(candidate_program)
            best_program = candidate_program
        end
        # Check stopping criteria
        if loop_enumerations >= max_enumerations || time() - start_time > max_time
            break
        end
    end
    if isnothing(best_program) && print_debug
        println("Did not find a better program")
    elseif print_debug
        println("Found a suboptimal program with distance: $(best_score)")
    end
    # The enumeration exhausted, but an optimal problem was not found
    return SearchStats(best_program, best_score, 1, loop_enumerations)
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