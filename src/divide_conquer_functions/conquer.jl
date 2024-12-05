
using DecisionTree

"""
	$(TYPEDSIGNATURES)

Takes in the problems with the found solutions and combines them into a global solution program 
by combining them into a decision tree.

 # Arguments
- `problems_to_solutions::Dict{Problem, Vector{RuleNode}}`: A dictionary mapping problems to their corresponding solution programs.
- `grammar::AbstractGrammar`: The grammar used to generate and evaluate programs.
- `n_predicates::Int`: The number of predicates generated to learn the decision tree.
- `sym_bool::Symbol`: The symbol representing boolean conditions in the grammar.
- `sym_start::Symbol`: The starting symbol of the grammar.
- `sym_constraint::Symbol`: The symbol used to constrain grammar when generating predicates.
- `symboltable::SymbolTable`: The symbol table used for evaluating expressions.

# Descritpion
Combines the progams that solve the sub-problems into a decision tree. To learn the decision tree, predicates are generated
that are then used to create feature vectors. TODO: continue...

# Returns


TODO!!!!

"""
function conquer_combine(
	problems_to_solutions::Dict{Problem, Vector{RuleNode}},
	grammar::AbstractGrammar,
	n_predicates::Int,
	sym_bool::Symbol,
	sym_start::Symbol,
	sym_constraint::Symbol,
	symboltable::SymbolTable,
)
	# make sure grammar has if-else rulenode
	return_type = grammar.rules[grammar.bytype[sym_start][1]] # return type of the starting symbol in the grammar
	idx_ifelse = findfirst(r -> r == :($sym_bool ? $return_type : $return_type), grammar.rules)
	if isnothing(idx_ifelse)
		throw(
			DecisionTreeError("No conditional if-else statement found in grammar. Please add one."),
		)
	end

	# Turn dic into vector since we cannot guarantee order when iterating over dict.
	ioexamples_solutions =
		[(example, sol) for (key, sol) in problems_to_solutions for example in key.spec]
	labels = get_labels(ioexamples_solutions)
	predicates = get_predicates(grammar, sym_bool, n_predicates)
	# Matrix of feature vectors. Feature vectors are created by evaluating an input from the IO examples on predicatess.
	features = get_features(
		ioexamples_solutions,
		predicates,
		grammar,
		symboltable,
		false,
	)
	features = float.(features)
	# Take labels and features to make DecisionTree
	# See decision tree example: https://github.com/Herb-AI/HerbSearch.jl/blob/subset-search/src/subset_iterator.jl
	model = DecisionTree.DecisionTreeClassifier()
	DecisionTree.fit!(model, features, labels)
	# TODO: What to do now?
	# TODO: better docs
end

"""
	Returns predicates that can serve as conditional statements for combining programs in a decision tree.
	The number of predicates returned is determined by `n_predicates`.
	`sym_bool` is used to make sure that only programs evaluate to `Bool` are considered. 
	`sym_constraint` is used to to further limit the program space to exclude trivial predicates.
"""
function get_predicates(grammar::AbstractGrammar,
	sym_bool::Symbol,
	sym_constraint::Symbol,
	n_predicates::Number,
)::Vector{RuleNode}
	# We get the first grammar rule that has the specified `sym_constraint` and add constraint to grammar. 
	clearconstraints!(grammar)
	idx_rule = grammar.bytype[sym_constraint][1]
	addconstraint!(grammar, Contains(idx_rule))

	iterator = BFSIterator(grammar, sym_bool)
	predicates = Vector{RuleNode}()

	for (i, candidate_program) ∈ enumerate(iterator)
		candidate_program = freeze_state(candidate_program)
		push!(predicates, candidate_program)
		if i >= n_predicates
			break
		end
	end
	return predicates
end

"""
	Returns a matrix containing the feature vectors for all problem/predicate combinations. 
	A feature vector is obtained by evaluating a `IOExample` in `ioexamples_solutions` on each
	predicate.
"""
function get_features(
	ioexamples_solutions::Vector{Tuple{IOExample, Vector{RuleNode}}},
	predicates::Vector{RuleNode},
	grammar::AbstractGrammar,
	symboltable::SymbolTable,
	allow_evaluation_errors::Bool = true,
)::Matrix{Bool}
	# features matrix with dimension n_ioexamples x n_predicates
	features = trues(length(ioexamples_solutions),
		length(predicates))
	for (i, (ioexample, _)) in enumerate(ioexamples_solutions)
		output = Vector()
		for pred in predicates
			expr = rulenode2expr(pred, grammar)
			try
				o = execute_on_input(symboltable, expr, ioexample.in) # will return Bool since we execute on predicates
				push!(output, o)
			catch err
				# TODO: When do we expect an EvaluatinError?
				# Throw the error if `allow_evaluation_errors` is false
				eval_error = EvaluationError(expr, ioexample.in, err)
				allow_evaluation_errors || throw(eval_error)
				push!(output, false)
			end
		end
		features[i, :] = output
	end
	return features
end

"""
	Returns a vector containing the labels for each `IOExample` in `ioexamples_solutions`.
	The label is the first program in the solutions vector.
"""
function get_labels(
	ioexamples_solutions::Vector{Tuple{IOExample, Vector{RuleNode}}},
)::Vector{String}
	# TODO: Does Vector{String} make sense as return type? Try RuleNode as labels
	# Use first solution probram as label for a problem
	labels = [string(solutions[1]) for (_, solutions) in ioexamples_solutions]
	return labels
end
