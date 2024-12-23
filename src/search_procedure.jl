# TODO: import functions

"""
	@enum SynthResult optimal_program=1 suboptimal_program=2

Representation of the possible results of the synth procedure. 
At the moment there are two possible outcomes:

- `optimal_program`: The synthesized program satisfies the entire program specification.
- `suboptimal_program`: The synthesized program does not satisfy the entire program specification, but got the best score from the evaluator.
"""
@enum SynthResult optimal_program = 1 suboptimal_program = 2

"""
	synth(problem::Problem, iterator::ProgramIterator; shortcircuit::Bool=true, allow_evaluation_errors::Bool=false, mod::Module=Main)::Union{Tuple{RuleNode, SynthResult}, Nothing}

Synthesize a program that satisfies the maximum number of examples in the problem.
		- problem                 - The problem definition with IO examples
		- iterator                - The iterator that will be used
		- shortcircuit            - Whether to stop evaluating after finding a single example that fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
		- allow_evaluation_errors - Whether the search should crash if an exception is thrown in the evaluation
		- max_time                - Maximum time that the iterator will run 
		- max_enumerations        - Maximum number of iterations that the iterator will run 
		- mod                     - A module containing definitions for the functions in the grammar that do not exist in Main

Returns a tuple of the rulenode representing the solution program and a synthresult that indicates if that program is optimal. `synth` uses `evaluate` which returns a score in the interval [0, 1] and checks whether that score reaches 1. If not it will return the best program so far, with the proper flag
"""
function synth(
	problem::Problem,
	iterator::ProgramIterator;
	shortcircuit::Bool = true,
	allow_evaluation_errors::Bool = false,
	max_time = typemax(Int),
	max_enumerations = typemax(Int),
	mod::Module = Main)::Union{Tuple{RuleNode, SynthResult}, Nothing}
	start_time = time()
	grammar = get_grammar(iterator.solver)
	symboltable::SymbolTable = SymbolTable(grammar, mod)

	best_score = 0
	best_program = nothing

	for (i, candidate_program) ∈ enumerate(iterator)
		# Create expression from rulenode representation of AST
		expr = rulenode2expr(candidate_program, grammar)

		# Evaluate the expression
		score = evaluate(
			problem,
			expr,
			symboltable,
			shortcircuit = shortcircuit,
			allow_evaluation_errors = allow_evaluation_errors,
		)
		if score == 1
			candidate_program = freeze_state(candidate_program)
			return (candidate_program, optimal_program)
		elseif score >= best_score
			best_score = score
			candidate_program = freeze_state(candidate_program)
			best_program = candidate_program
		end

		# Check stopping criteria
		if i > max_enumerations || time() - start_time > max_time
			break
		end
	end

	# The enumeration exhausted, but an optimal problem was not found
	return (best_program, suboptimal_program)
end


"""
	divide_and_conquer(problem:Problem)::Union{Tuple{RuleNode, SynthResult}, Nothing}
Synthesizes a program using a divide and conquer strategy. 

Breaks down the problem into smaller subproblems and synthesizes solutions for each subproblem (divide). The sub-solution programs are combined into a global solution program (conquer). 

# Arguments 
- `problem::Problem` : Specification of the program synthesis problem.
- `iterator::ProgramIterator` : Iterator over candidate programs that is used to search for solutions of the sub-programs.
- `divide::Function` : Function for dividing problems into sub-problems. It is assumed the function takes a `Problem` as input and returns an `AbstractVector<Problem>`.
- `max_time::Int` : Maximum time that the iterator will run 
- `max_enumerations::Int` : Maximum number of iterations that the iterator will run 
- `mod::Module` : A module containing definitions for the functions in the grammar. Defaults to `Main`.

Returns the `RuleNode` representing the final program constructed from the solutions to the subproblems.
"""
function divide_and_conquer(problem::Problem,
	iterator::ProgramIterator,
	divide::Function = divide_by_example,
	decide::Function = decide_if_solution,
	# conquer::Function = conquer_combine,
	max_time::Int = typemax(Int),
	max_enumerations::Int = typemax(Int),
	mod::Module = Main,
)
	start_time = time()
	grammar = get_grammar(iterator.solver)
	symboltable::SymbolTable = SymbolTable(grammar, mod)

	# Divide problem into sub-problems 
	subproblems = divide(problem)

	# Initialise a Dict that maps each subproblem to one or more solution programs
	problems_to_solutions::Dict{Problem, Vector{StateHole}} = Dict(p => [] for p in subproblems)
	for (i, candidate_program) ∈ enumerate(iterator)
		expr = rulenode2expr(candidate_program, grammar)
		for prob in subproblems
			keep_program = decide(prob, expr, symboltable)
			# TODO: We want to make all of this work also with StateHoles. Use `get_rulenode` for stateholes. Make deepcopy of program.
			if keep_program
				push!(problems_to_solutions[prob], deepcopy(candidate_program))
			end
		end
		# Stop if we have a solution to each subproblem, or reached max_enumerations/max_time
		if all(!isempty, values(problems_to_solutions)) || i > max_enumerations ||
		   time() - start_time > max_time
			break
		end


	end

	# n_predicates = 5
	# TODO: add if-else rule to grammar
	# final_program = conquer_combine(
	# 	problems_to_solutions,
	# 	grammar,
	# 	n_predicates,
	# 	sym_bool::Symbol,
	# 	:Start,
	# 	:Start,
	# 	symboltable,
	# )

	# return conquer(problems_to_solutions) # TODO: implement conquer
	# return (problems_to_solutions, subproblems)
	return problems_to_solutions
	# TODO: How reusable is our API for decide, divide, conquer
end


