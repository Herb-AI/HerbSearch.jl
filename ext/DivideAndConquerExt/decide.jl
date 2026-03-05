"""
	$(TYPEDSIGNATURES)

Indicates whether to keep a program as a solution to the provided subproblem.
Returns `True` if the program solves the given problem.

# Arguments
- `problem`: specification of the (sub)problem
- `expr`: Corresponding Julia expression of the program under decision
- `symboltable`: The symbol table used for evaluating expressions.
"""
# New fast overload (no expr, no symboltable)
function decide(
    problem::Problem,
    program::AbstractRuleNode,
    interp::F;
    eq::Function = (==),
    allow_errors::Bool = true,
) where {F}
    for ex in problem.spec
        ok = false
        if allow_errors
            try
                # prefer IOExample overload (fast + matches your tests)
                y = interp(program, ex)
                ok = eq(y, ex.out)
            catch err
				@show err
                ok = false
            end
        else
            y = interp(program, ex)
            ok = eq(y, ex.out)
        end

        ok || return false
    end
    return true
end