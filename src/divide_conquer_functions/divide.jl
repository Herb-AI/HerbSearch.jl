"""
    $(TYPEDSIGNATURES)

Breaks the problem specification into individual input-output examples and returns a vector containing all individual problems. 
"""
function divide_by_example(problem::Problem{Vector{IOExample}})::Vector{Problem{Vector{IOExample}}}
    # TODO
    subproblems = Vector{Problem{Vector{IOExample}}}()
    for p in problem.spec
        push!(subproblems, Problem([p]))
    end
    return subproblems
end
