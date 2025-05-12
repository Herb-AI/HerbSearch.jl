"""
	AuxFunction(func::Function, best_value::Number)

A wrapper struct for auxiliary evaluation functions used in the Aulile learning loop.

- `func`: A function that returns a score based on an `IOExample` and the candidate output.
- `best_value`: The target score the synthesizer attempts to minimize. When a program achieves this score across all examples, 
    it is considered optimal.
"""
struct AuxFunction
    func::Function
    best_value::Number # NOTE: Aulile tries to *minimize* to this value
end

# Make `AuxFunction` behave like a regular callable function.
function (af::AuxFunction)(example::IOExample, output)
    return af.func(example, output)
end

"""
	aulile(problem::Problem, iter_t::Type{<:ProgramIterator}, grammar::AbstractGrammar, start_symbol::Symbol, aux::AuxFunction; 
        max_iterations=5, max_depth=5, max_enumerations=100000) -> Union{Tuple{RuleNode, SynthResult}, Nothing}

Performs iterative library learning (Aulile) by enumerating programs using a grammar and synthesizing programs that 
    minimize the auxiliary scoring function across `IOExample`s.

- `problem`: A `Problem` object containing a list of `IOExample`s.
- `iter_t`: Type of program iterator to use (must be constructible with grammar and symbol).
- `grammar`: The grammar used to generate candidate programs.
- `start_symbol`: The non-terminal symbol representing the start of the grammar.
- `aux`: An `AuxFunction` that defines the evaluation metric and desired score.
- `interpret`: An interpret function for the grammar
- `get_relevant_tags`: A grammar to tags converter specific to the problem
- `max_iterations`: Maximum number of learning iterations to perform.
- `max_depth`: Maximum depth for program enumeration.
- `max_enumerations`: Maximum number of candidate programs to try per iteration.

Returns a tuple of the best discovered program and a `SynthResult` (either `optimal_program` or `suboptimal_program`), 
    or `nothing` if no program was found.
"""
function aulile(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iter_t::Type{<:ProgramIterator},
    grammar::AbstractGrammar,
    start_symbol::Symbol,
    aux::AuxFunction;
    interpret::Union{Function,Nothing}=nothing,
    get_relevant_tags::Union{Function,Nothing}=nothing,
    max_iterations=5,
    max_depth=5,
    max_enumerations=100000)::Union{Tuple{RuleNode,SynthResult},Nothing}

    if !(interpret isa Nothing)
        @assert !(get_relevant_tags isa Nothing)
    end

    iter = iter_t(grammar, start_symbol, max_depth=max_depth)
    program = nothing

    # Get initial distance of input and output
    best_score = 0
    for problem ∈ problem.spec
        best_score += aux(problem, only(values(problem.in))) # Assume single input argument
    end
    println("Initial Distance: $(best_score)")

    for i in 1:max_iterations
        if interpret isa Nothing
            result = synth_with_aux(problem, iter, grammar, aux, best_score,
                max_enumerations=max_enumerations)
        else
            result = synth_with_aux(problem, iter, grammar, aux, best_score, something(interpret),
                something(get_relevant_tags), max_enumerations=max_enumerations)
        end
        if result isa Nothing
            return nothing
        else
            program, new_score = result
            @assert new_score < best_score
            best_score = new_score
            if best_score <= aux.best_value
                return program, optimal_program
            else
                add_rule!(grammar, program)
                iter = iter_t(grammar, start_symbol, max_depth=max_depth)
            end
            println("Grammar after step $(i): \n $(grammar) \n")
        end
    end

    return program, suboptimal_program
end

"""
	synth_with_aux(problem::Problem, iterator::ProgramIterator, grammar::AbstractGrammar, aux::AuxFunction, 
        best_score::Int, interpret::Function, get_relevant_tags::Function; allow_evaluation_errors=false, 
        max_time=typemax(Int), max_enumerations=typemax(Int), mod=Main) -> Union{Tuple{RuleNode, Int}, Nothing}

Searches for the best program that minimizes the score defined by the auxiliary function.

- `problem`: The problem definition with IO examples.
- `iterator`: Program enumeration iterator.
- `grammar`: Grammar used to generate and interpret programs.
- `aux`: An `AuxFunction` used to compute score between program output and expected output.
- `best_score`: Current best score to beat.
- `interpret`: An interpret function for the grammar
- `get_relevant_tags`: A grammar to tags converter specific to the problem
- `allow_evaluation_errors`: Whether to tolerate runtime exceptions during evaluation.
- `max_time`: Maximum allowed runtime for the synthesis loop.
- `max_enumerations`: Maximum number of candidate programs to try.
- `mod`: Module in which to resolve symbols from the grammar.

Returns a tuple `(program, score)` of the best discovered program and its score. Returns `nothing` if no better 
    program was found.
"""
function synth_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iterator::ProgramIterator,
    grammar::AbstractGrammar,
    aux::AuxFunction,
    best_score::Int,
    interpret::Function,
    get_relevant_tags::Function;
    allow_evaluation_errors::Bool=false,
    max_time=typemax(Int),
    max_enumerations=typemax(Int),
    mod::Module=Main)::Union{Tuple{RuleNode,Int},Nothing}

    objective_states = [pair.out for pair in problem.spec]
    for (i, program) ∈ enumerate(iterator)
        states = [only(values(problem.in)) for problem in problem.spec]
        # Can add this back for efficiency but needs a new function argument 
        # grammartags = HerbBenchmarks.String_transformations_2020.get_relevant_tags(grammar) 

        solved = true
        for (objective_state, state) in zip(objective_states, states)
            try
                final_state = interpret(program, grammartags, state)

                if objective_state != final_state
                    solved = false
                    break
                end
            catch BoundsError
                break
            end
        end

        if solved
            return (program, 0)
        end
    end
end

"""
	synth_with_aux(problem::Problem, iterator::ProgramIterator, grammar::AbstractGrammar, aux::AuxFunction, 
        best_score::Int; allow_evaluation_errors=false, max_time=typemax(Int), max_enumerations=typemax(Int), 
        mod=Main) -> Union{Tuple{RuleNode, Int}, Nothing}

Searches for the best program that minimizes the score defined by the auxiliary function.

- `problem`: The problem definition with IO examples.
- `iterator`: Program enumeration iterator.
- `grammar`: Grammar used to generate and interpret programs.
- `aux`: An `AuxFunction` used to compute score between program output and expected output.
- `best_score`: Current best score to beat.
- `allow_evaluation_errors`: Whether to tolerate runtime exceptions during evaluation.
- `max_time`: Maximum allowed runtime for the synthesis loop.
- `max_enumerations`: Maximum number of candidate programs to try.
- `mod`: Module in which to resolve symbols from the grammar.

Returns a tuple `(program, score)` of the best discovered program and its score. Returns `nothing` if no better 
    program was found.
"""
function synth_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iterator::ProgramIterator,
    grammar::AbstractGrammar,
    aux::AuxFunction,
    best_score::Int;
    allow_evaluation_errors::Bool=false,
    max_time=typemax(Int),
    max_enumerations=typemax(Int),
    mod::Module=Main)::Union{Tuple{RuleNode,Int},Nothing}

    start_time = time()
    symboltable = grammar2symboltable(grammar, mod)
    best_program = nothing

    for (i, candidate_program) ∈ enumerate(iterator)
        # Create expression from rulenode representation of AST
        expr = rulenode2expr(candidate_program, grammar)
        # Evaluate the expression
        score = evaluate_with_aux(
            problem,
            expr,
            symboltable,
            aux,
            allow_evaluation_errors=allow_evaluation_errors,
        )
        # Update score if better
        if score == aux.best_value
            candidate_program = freeze_state(candidate_program)
            println("Found an optimal program!")
            return (candidate_program, aux.best_value)
        elseif score < best_score
            best_score = score
            candidate_program = freeze_state(candidate_program)
            best_program = candidate_program
        end
        # Check stopping criteria
        if i > max_enumerations || time() - start_time > max_time
            break
        end
    end

    if isnothing(best_program)
        println("Did not find a better program")
        return nothing
    end

    println("Found a suboptimal program with distance: $(best_score)")
    println(rulenode2expr(best_program, grammar))

    # The enumeration exhausted, but an optimal problem was not found
    return (best_program, best_score)
end

"""
	evaluate_with_aux(problem::Problem, expr::Any, symboltable::SymbolTable, aux::AuxFunction; 
        allow_evaluation_errors=false) -> Number

Evaluates a candidate program (given as an expression) over all examples in a problem using the auxiliary evaluation 
    function.

- `problem`: The problem definition with IO examples.
- `expr`: The candidate program expression to evaluate.
- `symboltable`: Symbol table used to evaluate functions in the expression.
- `aux`: An `AuxFunction` used to compute the score between expected and actual output.
- `allow_evaluation_errors`: Whether evaluation errors should be tolerated or raise an exception.

Returns the total distance score. If evaluation errors are disallowed and one occurs, an `EvaluationError` is thrown.
"""
function evaluate_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    expr::Any,
    symboltable::SymbolTable,
    aux::AuxFunction;
    allow_evaluation_errors::Bool=false
)::Number
    distance_in_examples = 0

    crashed = false
    for example ∈ problem.spec
        try
            output = execute_on_input(symboltable, expr, example.in)
            distance_in_examples += aux(example, output)
        catch e
            # You could also decide to handle less severe errors (such as index out of range) differently,
            # for example by just increasing the error value and keeping the program as a candidate.
            crashed = true
            # Throw the error again if evaluation errors aren't allowed
            eval_error = EvaluationError(expr, example.in, e)
            allow_evaluation_errors || throw(eval_error)
            break
        end
    end
    return distance_in_examples
end