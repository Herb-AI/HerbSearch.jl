
using DecisionTree
struct ConditionalIfElseError <: Exception
	msg::String
end

function Base.showerror(io::IO, e::ConditionalIfElseError)
	print(io, e.msg)
end

"""
	$(TYPEDSIGNATURES)

Takes in the problems with the found solutions and combines them into a global solution program 
by combining them into a decision tree.

 # Arguments
- `problems_to_solutions`: A dictionary mapping problems to the index of their corresponding solution program in `solutions`.
- `solutions`: A vector containing the solutions to the problems
- `grammar`: The grammar used to generate and evaluate programs.
- `n_predicates`: The number of predicates generated to learn the decision tree.
- `sym_bool`: The symbol representing boolean conditions in the grammar.
- `sym_start`: The starting symbol of the grammar.
- `sym_constraint`: The symbol used to constrain grammar when generating predicates.
- `symboltable`: The symbol table used for evaluating expressions.

# Description
Combines the progams that solve the sub-problems into a decision tree. To learn the decision tree, labels and features are required.
The solutions to the problems are used as labels. Predicates from the grammar serve as coniditional statements to combine the programs 
in the decision tree. For this, features are obtained by evaluating the inputs of the examples on the predicates. 

# Returns

The final program constructed from the solutions to the subproblems.
"""
function conquer_combine(
	problems_to_solutions::Dict{Problem{Vector{IOExample{T, U}}}, Vector{Int}},
	# solutions::Vector{Union{RuleNode, StateHole}},
	solutions::Vector{RuleNode},
	grammar::AbstractGrammar,
	n_predicates::Int,
	sym_bool::Symbol,
	sym_start::Symbol,
	sym_constraint::Symbol,
	symboltable::SymbolTable,
) where {T, U}
	# make sure grammar has if-else rulenode (TODO: do we need this? )
	idx_ifelse = findfirst(r -> r == :($sym_bool ? $sym_start : $sym_start), grammar.rules)
	if isnothing(idx_ifelse)
		throw(
			ConditionalIfElseError(
				"No conditional if-else statement found in grammar. Please add one.",
			),
		)
	end

	# Turn dic into vector since we cannot guarantee order when iterating over dict.
	ioexamples_solutions =
		[
			(example, [idx for idx in vec]) for (prob, vec) in problems_to_solutions for
			example in prob.spec
		]

	labels = get_labels(ioexamples_solutions)
	predicates = get_predicates(grammar, sym_bool, sym_constraint, n_predicates)
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
	final_program = construct_final_program(model.root.node, idx_ifelse, solutions, predicates)
	return final_program
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

# TODO: doc strings
"""
	Returns a matrix containing the feature vectors for all problem/predicate combinations. 
	A feature vector is obtained by evaluating a `IOExample` in `ioexamples_solutions` on each
	predicate.
"""
function get_features(
	ioexamples_solutions::Vector{Tuple{IOExample{T, U}, Vector{Int}}},
	predicates::Vector{RuleNode},
	grammar::AbstractGrammar,
	symboltable::SymbolTable,  # or symboltable::AbstractSymbolTable if that exists
	allow_evaluation_errors::Bool = true,
) where {T, U}
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
	The label is the index of the first program in the vector of solutions for a `IOExample`.
"""
function get_labels(ioexamples_solutions::Vector{Tuple{IOExample{T, U}, Vector{Int}}}) where {T, U}
	# TODO: update docstring 
	# Use index of first program in vector of solutions as label for a problem
	labels = [sol[1] for (_, sol) in ioexamples_solutions]
	return labels
end

"""
	$(TYPEDSIGNATURES)

Construct the final program by converting a decision tree into a RuleNode.

# Arguments
- `node}`: The current node in the decision tree. Can be either
  an internal node or a leaf node.
- `idx_ifelse`: Index of the if-else rule in the grammar.
- `labels_to_programs`: Dictionary that maps a label to the corresponding subprogram.
- `predicates`: Vector of predicates used for feature tests in the decision tree.

# Description
Recursively traverses a decision tree and constructs an equivalent `RuleNode`.
For each internal node in the decision tree, the function creates a conditional `RuleNode` using the node's
feature. When a leaf node is reached, it returns the program corresponding to the 
leaf node's label from `labels_to_programs`. 

# Returns
- `RuleNode`: The final program derived from the decision tree. It combines solutions to sub-problems using conditional statements
and features derived from the `predicates`.
```
"""
# function construct_final_program(
# 	node::Union{DecisionTree.Node, DecisionTree.Leaf},
# 	idx_ifelse::Int64,
# 	solutions::Vector{T},
# 	predicates::Vector{RuleNode},
# )::RuleNode where T <: Union{RuleNode, StateHole}
function construct_final_program(
	node::Union{DecisionTree.Node, DecisionTree.Leaf},
	idx_ifelse::Int64,
	solutions::Vector{RuleNode},
	predicates::Vector{RuleNode},
)::RuleNode
	if DecisionTree.is_leaf(node)
		# TODO: convert StateHole to RuleNode
		return solutions[node.majority]
	end

	l = construct_final_program(node.left, idx_ifelse, solutions, predicates)
	r = construct_final_program(node.right, idx_ifelse, solutions, predicates)

	# Note: Order has to be r, l. DecisionTree.jl splits data by comparing a feature against a threshold. Since we use
	# predicates to get features, the feature values will be true/false (1.0/0.0) and the threshold 0.5.
	# Hence, the left edge of a node is for feature == false, right edge for feature == true.
	# See also test for an example.
	condition = RuleNode(idx_ifelse, Vector{RuleNode}([predicates[node.featid], r, l]))
	return condition
end

# TODO: use `get_rulenode` to convert StateHole to RuleNode