using Markdown
using InteractiveUtils
include("RefactorExt.jl")
using .RefactorExt
include("../../src/HerbSearch.jl")
using HerbCore, HerbGrammar, .HerbSearch, HerbSpecification, HerbBenchmarks, HerbConstraints
using DataStructures: PriorityQueue, dequeue!, dequeue_pair!

"""
    Prints test message (name) and returns the start time
"""
function print_time_test_start(message::AbstractString; print_separating_dashes=true)::DateTime
    if print_separating_dashes
        println()
        println("--------------------------------------------------")
    end
    printstyled(message * "\n"; color=:blue)
    if print_separating_dashes
        println("--------------------------------------------------")
    end
    return Dates.now()
end

"""
    Prints and returns the duration of the test
"""
function print_time_test_end(start_time::DateTime; end_time::DateTime=Dates.now(), test_passed=true)::DateTime
    duration = max(end_time - start_time, Dates.Millisecond(0))
    println()
    if test_passed
        printstyled("Pass. Duration: "; color=:green)
    else
        printstyled("Fail. Duration: "; color=:red)
    end
    println("$(duration)")
    return duration
end


function knorf(
    problem::Problem{<:AbstractVector{<:IOExample}},
    iterator::Type{<:ProgramIterator},
    grammar::AbstractGrammar,
    max_iterations=100,
    best_solutions_per_iteration=10,
    max_enumerations=10000,
    shortcircuit::Bool=true,
    k=1
)::Union{Tuple{Rulenode, SynthResult}, Nothing}

    best_program = nothing
    best_score = 0

    for j in 1:max_iterations
        symboltable :: SymbolTable = grammar2symboltable(grammar, mod)

        best_programs = PriorityQueue{<:AbstractRuleNode, Number}()
        
        for (i, candidate_program) ∈ enumerate(iterator)
            # Create expression from rulenode representation of AST
            expr = rulenode2expr(candidate_program, grammar)

            # Evaluate the expression
            score = evaluate(problem, expr, symboltable, shortcircuit=shortcircuit, allow_evaluation_errors=false)
            if score == 1
                # Shortcircuit when an optimal program is found
                candidate_program = freeze_state(candidate_program)
                return (candidate_program, optimal_program)
            else
                best_programs[candidate_program] = score
                if length(best_programs) > best_solutions_per_iteration
                    dequeue!(best_programs)
                end
            end

            # Check stopping criteria
            if i > max_enumerations
                break;
            end
        end

        # The enumeration exhausted, but an optimal problem was not found
        grammar = RefactorExt.HerbSearch.refactor_grammar(programs, grammar, k)

        while length(best_programs) > 1
            dequeue!(best_programs)
        end 

        program, score = dequeue_pair!(best_programs)
        if score > best_score
            best_program = program
        end
    end

    return (best_program, suboptimal_program)
end


