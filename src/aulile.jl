function aulile(
    problem::Problem{<:AbstractVector{<:IOExample}}, 
    iter::ProgramIterator,
    aux::Function,
    max_iterations=5, 
    max_enumerations = 1000000)::Union{Tuple{RuleNode, SynthResult}, Nothing}

    grammar = get_grammar(iter.solver)
    result = nothing
    for i in 1:max_iterations
        result = synth_with_aux(problem, iter, grammar, aux, max_enumerations=max_enumerations)
        if result isa Nothing
            return nothing
        else 
            program, synth_result = result
            if synth_result == optimal_program
                return result
            else 
                add_rule!(grammar, program)
            end
            println("Grammar after step $(i): \n $(grammar) \n")
        end
    end

    return result
end

function synth_with_aux(
	problem::Problem{<:AbstractVector{<:IOExample}},
	iterator::ProgramIterator,
    grammar::AbstractGrammar,
    aux::Function;
	shortcircuit::Bool = true,
	allow_evaluation_errors::Bool = false,
	max_time = typemax(Int),
	max_enumerations = typemax(Int),
	mod::Module = Main)::Union{Tuple{RuleNode, SynthResult}, Nothing}

	start_time = time()
	symboltable = grammar2symboltable(grammar, mod)

    # Get initial distance of input and output
	best_score = 0
    for problem ∈ problem.spec
        best_score += aux(problem, problem.in[:x]) 
    end
    println("Initial Distance: $(best_score)")

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
			shortcircuit = shortcircuit,
			allow_evaluation_errors = allow_evaluation_errors,
		)
		if score == 0
			candidate_program = freeze_state(candidate_program)
            println("Found an optimal program!")
			return (candidate_program, optimal_program)
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

    println("Found a suboptimal program with distance: $(best_score)")
    println(rulenode2expr(best_program, grammar))

	# The enumeration exhausted, but an optimal problem was not found
	return (best_program, suboptimal_program)
end

function evaluate_with_aux(
    problem::Problem{<:AbstractVector{<:IOExample}},
    expr::Any,
    symboltable::SymbolTable, 
    aux::Function;
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

    return distance_in_examples;
end