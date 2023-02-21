"""
Structure used to track the context.
Contains the expression being modified and the path to the current node.
"""
mutable struct GrammarContext
	originalExpr::RuleNode    	# original expression being modified
	nodeLocation::Vector{Int}   # path to he current node in the expression, 
                                # a sequence of child indices for each parent
end

GrammarContext(originalExpr::RuleNode) = GrammarContext(originalExpr, [])

"""
Adds a parent to the context.
The parent is defined by the grammar rule id.
"""
function addparent!(context::GrammarContext, parent::Int)
	push!(context.nodeLocation, parent)
end


"""
Copies the given context and insert the parent in the node location.
"""
function copy_and_insert(old_context::GrammarContext, parent::Int)
	new_context = GrammarContext(old_context.originalExpr, deepcopy(old_context.nodeLocation))
	push!(new_context.nodeLocation, parent)
	new_context
end