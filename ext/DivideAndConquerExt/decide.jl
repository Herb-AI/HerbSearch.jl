"""
	$(TYPEDSIGNATURES)

Indicates whether to keep a program as a solution to the provided subproblem.
Returns `True` if the program solves the given problem.

# Arguments
- `problem`: specification of the (sub)problem
- `program`: the candidate program under decision
- `interp`: compiled interpreter (see `HerbInterpret.make_interpreter`) used to run `program`
"""
function decide(
    problem::Problem,
    program::AbstractRuleNode,
    interp::F;
    eq::Function = (==),
    allow_errors::Bool = true,
) where {F}
    for ex in problem.spec
        if allow_errors
            try
                y = interp(program, ex)
                eq(y, ex.out) || return false
            catch err
                return false
            end
        else
            y = interp(program, ex)
            eq(y, ex.out) || return false
        end
    end
    return true
end
