module DivideAndConquerExt

using HerbSearch
using HerbCore
using HerbSpecification
using HerbGrammar
using HerbConstraints
using HerbInterpret
using DecisionTree
using DocStringExtensions

include("divide.jl")
include("decide.jl")
include("conquer.jl")

"""
		$(TYPEDSIGNATURES)
Synthesizes a program using a divide and conquer strategy.

First it divides the problem into one subproblem per example (`divide`), and searches `iterator` for a program
that solves each subproblem on its own. Then it combines those per-example programs into one program that
handles every example, by learning a decision tree: the per-example programs become the tree's leaves, and
`sym_bool`-typed predicates from the grammar become the tree's branching conditions (`conquer`).

This is the strategy EUSolver uses to build a single program out of per-example solutions:
Xujie Si, Yuan Yang, Hanjun Dai, Mayur Naik, and Le Song. 2019. Learning a Meta-Solver for Syntax-Guided
Program Synthesis. In 7th International Conference on Learning Representations, ICLR 2019, New Orleans,
LA, USA, May 6-9, 2019.

# Arguments
- `problem::Problem` : Specification of the program synthesis problem.
- `iterator::ProgramIterator` : Iterator over candidate programs that is used to search for solutions of the sub-programs.
- `n_predicates`: The number of predicates generated to learn the decision tree.
- `sym_bool`: The symbol representing boolean conditions in the grammar.
- `sym_start`: The starting symbol of the grammar.
- `sym_constraint`: The symbol used to constrain grammar when generating predicates.
- `max_time::Int` : Maximum time that the iterator will run
- `max_enumerations::Int` : Maximum number of iterations that the iterator will run
- `mod::Module` : A module containing definitions for the functions in the grammar. Defaults to `Main`.

Returns a tuple `(final_program, programs_iterated)`. `final_program` is the assembled `RuleNode`, or `nothing`
if either some example has no solution at all, or the decision tree could not be built into a program that is
verified to solve every example. `programs_iterated` is how many candidate programs `iterator` produced before
the search stopped.

# Example

A grammar for integer arithmetic with an if-else rule (needed so `conquer` has something to combine
sub-programs with), used to learn `abs`. The literals only go up to 1, so `7` cannot be matched by a
literal and the search is forced to actually use `_arg_1`:

```julia
grammar = @csgrammar begin
    Integer = |(0:1)
    Input = _arg_1
    Integer = Input
    Integer = Integer + Integer
    Integer = Integer - Integer
    Condition = Integer <= Integer
    Integer = Condition ? Integer : Integer
end

problem = Problem([
    IOExample(Dict(:_arg_1 => 7), 7),   # abs(7) == 7
    IOExample(Dict(:_arg_1 => -7), 7),  # abs(-7) == 7
])

iterator = BFSIterator(grammar, :Integer)
final_program, programs_iterated = divide_and_conquer(
    problem, iterator,
    :Condition, # sym_bool: which nonterminal produces the if-condition
    :Integer,   # sym_start: the nonterminal the whole program is built from
    :Input,     # sym_constraint: predicates must actually depend on the input
)
```

`divide` finds one sub-program per example (`_arg_1` solves the first, `0 - _arg_1` solves the second), and
`conquer` picks a predicate on `_arg_1` that tells the two examples apart, then wraps both sub-programs in an
if-else RuleNode. Which exact predicate it picks depends on enumeration order (`_arg_1 <= 0` and `_arg_1 <= 1`
both work here), but the resulting `final_program` always computes `abs` on both examples.
"""
function HerbSearch.divide_and_conquer(
    problem::Problem,
    iterator::ProgramIterator,
    sym_bool::Symbol,
    sym_start::Symbol,
    sym_constraint::Symbol,
    n_predicates::Int = 100,
    max_time::Int = typemax(Int),
    max_enumerations::Int = typemax(Int),
    mod::Module = Main;
    interp = nothing,
    cache_module::Module = mod,
    allow_errors::Bool = true,
    print_errors::Bool = false,
)
    start_time = time()
    grammar = get_grammar(iterator)

    # Compile interpreter once if not provided
    if isnothing(interp)
        interp = HerbInterpret.make_interpreter(
            grammar;
            target_module = mod,
            cache_module  = cache_module,
        )
    end

    # Divide problem into sub-problems
    subproblems = divide(problem)

    problems_to_solutions = Dict(p => Vector{Int}() for p in subproblems)
    solutions = Vector{RuleNode}()
    idx = 0
	programs_iterated = nothing

    for (i, candidate_program) ∈ enumerate(iterator)
        is_added = false
		programs_iterated = i

        for prob in subproblems
            keep_program = decide(prob, candidate_program, interp;
                                  allow_errors=allow_errors)

            if keep_program
                if !is_added
                    if typeof(candidate_program) == StateHole
                        push!(solutions, freeze_state(candidate_program))
                    else
                        push!(solutions, deepcopy(candidate_program))
                    end
                    is_added = true
                    idx += 1
                end
                push!(problems_to_solutions[prob], idx)
            end
        end


        if all(!isempty, values(problems_to_solutions)) || i > max_enumerations ||
           time() - start_time > max_time
            break
        end
    end

	if any(isempty, values(problems_to_solutions))
		return nothing, programs_iterated
	end

    final_program = conquer(
        problems_to_solutions,
        solutions,
        grammar,
        n_predicates,
        sym_bool,
        sym_start,
        sym_constraint,
        interp,
    )

    return final_program, programs_iterated
end

end # module
