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

Breaks down the problem into smaller subproblems and synthesizes solutions for each subproblem (divide). The sub-solution programs are combined into a global solution program (conquer). 

# Arguments 
- `problem::Problem` : Specification of the program synthesis problem.
- `iterator::ProgramIterator` : Iterator over candidate programs that is used to search for solutions of the sub-programs.
- `divide::Function` : Function for dividing problems into sub-problems. It is assumed the function takes a `Problem` as input and returns an `AbstractVector<Problem>`.
- `n_predicates`: The number of predicates generated to learn the decision tree.
- `sym_bool`: The symbol representing boolean conditions in the grammar.
- `sym_start`: The starting symbol of the grammar.
- `sym_constraint`: The symbol used to constrain grammar when generating predicates.
- `max_time::Int` : Maximum time that the iterator will run 
- `max_enumerations::Int` : Maximum number of iterations that the iterator will run 
- `mod::Module` : A module containing definitions for the functions in the grammar. Defaults to `Main`.

Returns the `RuleNode` representing the final program constructed from the solutions to the subproblems.
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
		   @show all(!isempty, values(problems_to_solutions)) 
		   @show i > max_enumerations 
           @show time() - start_time > max_time
            break
        end
    end

	if any(isempty, values(problems_to_solutions))
		return nothing, programs_iterated
	end

	symboltable = grammar2symboltable(grammar, mod)

    final_program = conquer(
        problems_to_solutions,
        solutions,
        grammar,
        n_predicates,
        sym_bool,
        sym_start,
        sym_constraint,
        symboltable,
    )

    return final_program, programs_iterated
end

end # module
