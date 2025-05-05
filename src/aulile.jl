struct AuxFunction
    func::Function
    best_value::Number # NOTE: Aulile tries to *minimize* to this value
end

# Allow calling AuxFunction like a regular function
function (af::AuxFunction)(example::IOExample, output)
    return af.func(example, output)
end

function aulile(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iter::ProgramIterator,
    start_symbol::Symbol,
    aux::AuxFunction,
    max_iterations=5,
    max_enumerations=100000)::Union{Tuple{RuleNode,SynthResult},Nothing}

    grammar = get_grammar(iter.solver)
    program = nothing

    # Get initial distance of input and output
    best_score = 0
    for problem ∈ problem.spec
        best_score += aux(problem, problem.in[:x])
    end
    println("Initial Distance: $(best_score)")

    for i in 1:max_iterations
        result = synth_with_aux(problem, iter, grammar, aux, best_score, max_enumerations=max_enumerations)
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
                iter = typeof(iter)(grammar, start_symbol, max_depth=iter.solver.max_depth)
            end
            println("Grammar after step $(i): \n $(grammar) \n")
        end
    end

    return program, suboptimal_program
end

function synth_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iterator::ProgramIterator,
    grammar::AbstractGrammar,
    aux::AuxFunction,
    best_score::Int;
    shortcircuit::Bool=true,
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
            shortcircuit=shortcircuit,
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

function evaluate_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    expr::Any,
    symboltable::SymbolTable,
    aux::AuxFunction;
    shortcircuit::Bool=true,
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