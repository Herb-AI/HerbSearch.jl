"""
	$(TYPEDSIGNATURES)

Breaks the problem specification into individual problems with each of them being a single input-output example.
Returns a vector containing all individual subproblems. 
"""
function divide_by_example(problem::Problem{Vector{IOExample}})::Vector{Problem{Vector{IOExample}}}
	subproblems = Vector{Problem{Vector{IOExample}}}()
	for p in problem.spec
		push!(subproblems, Problem([p]))
	end
	return subproblems
end
