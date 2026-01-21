module ConflictAnalysisExt

using HerbSearch
using HerbCore
using HerbGrammar
using HerbSpecification
using HerbConstraints
using HerbInterpret
using DataStructures
using Satisfiability
using DocStringExtensions
using MLStyle


include("data.jl")
include("techniques/muc.jl")
include("techniques/era.jl")
include("techniques/sean.jl")
include("pipeline.jl")


"""
		$(TYPEDSIGNATURES)
Synthesizes a program using conflict analysis. 

Uses the defined techniques, implementations can be found in the techniques folder, and synthesizes a program while eliminating candidate programs during search. 

# Arguments 
- `problem::Problem` : Specification of the program synthesis problem.
- `iterator::ProgramIterator` : Iterator over candidate programs that is used to search for solutions of the sub-programs.
- `interpret::Function` : Function for custom interpreting a candidate solution and input.
- `max_time::Int` : Maximum time that the iterator will run 
- `max_enumerations::Int` : Maximum number of iterations that the iterator will run 
- `mod::Module` : A module containing definitions for the functions in the grammar. Defaults to `Main`.
- `techniques::Vector{Symbol}` : A vector of symbols representing the conflict analysis techniques to use.

Returns the `RuleNode` representing the final program constructed from the solutions to the subproblems. Can also return `nothing` if no solution is found within the constraints.
"""
function HerbSearch.conflict_analysis(
    problem::Problem,
    iterator::ProgramIterator,
    interpret::Union{Function, Nothing} = nothing;
    max_time = typemax(Int),
    max_enumerations = typemax(Int),
    mod::Module = Main,
    techniques::Vector{Symbol} = [:ERA, :MUC, :SeAn]

)::Tuple{Union{AbstractRuleNode, Nothing}, Int64, Int64}
    start_time   = time()
    solver       = iterator.solver
    grammar      = get_grammar(solver)
    grammar_tags = isnothing(interpret) ? nothing : get_relevant_tags(grammar)
    symboltable  = grammar2symboltable(grammar, mod)
    counter      = 0
    cons_counter = 0

    techs = build_techniques(techniques)

    for (i, candidate_program) ∈ enumerate(iterator)
        counter = i
        expr = rulenode2expr(candidate_program, grammar)
        output, result, counter_example = isnothing(interpret) ? 
            evaluate(expr, problem, symboltable) : 
            evaluate(candidate_program, problem, grammar_tags, interpret)

        if result == success
            return (freeze_state(candidate_program), counter, cons_counter)
        else
            ctx = ConflictContext(grammar, symboltable, candidate_program, output, counter_example)
            constraints, grammar_constraints = run_conflict_pipeline(techs, ctx)
            
            for c in grammar_constraints
                addconstraint!(grammar, c.cons)
            end
            if !isempty(constraints)
                HerbSearch.add_constraints!(iterator, AbstractGrammarConstraint[c.cons for c in constraints])
            end

            cons_counter += length(constraints) + length(grammar_constraints)
        end

        if i > max_enumerations || time() - start_time > max_time
            println("Stopping criteria met")
            break
        end
    end

    # Clean up
    for t in techs
        try
            close(t)
        catch _
            # ignore if technique has no resources
        end
    end

    return (nothing, counter, cons_counter)
end

"""
Gets relevant symbol to easily match grammar rules to operations in `interpret` function
"""
function get_relevant_tags(grammar::ContextSensitiveGrammar)
    tags = Dict{Int,Any}()
    for (ind, r) in pairs(grammar.rules)
        tags[ind] = if typeof(r) != Expr
            r
        else
            @match r.head begin
                :block => :OpSeq
                :call => r.args[1]
                :if => :IF
            end
        end
    end
    return tags
end

"""
    execute_on_input(tab::SymbolTable, expr::Any, input::Dict{Symbol, T}, interpret::Function)::Any where T

Custom execute_on_input function that uses a given interpret function.
"""
function HerbSearch.execute_on_input(program::AbstractRuleNode, grammar_tags::Dict{Int, Any}, input::Dict{Symbol, T}, interpret::Function)::Any where T
    return interpret(program, grammar_tags, input)
end

@enum EvalResult success=1 failed=2 crashed=3
"""
    evaluate(
        expr::Any,
        problem::Problem{<:AbstractVector{<:IOExample}},
        symboltable::SymbolTable
    )::Tuple{Union{Any, Nothing}, EvalResult, Union{<:IOExample, Nothing}}

Evaluate the expression on the examples using the given symboltable.
"""
function evaluate(
    expr::Any,
    problem::Problem{<:AbstractVector{<:IOExample}},
    symboltable::SymbolTable
)::Tuple{Union{Any, Nothing}, EvalResult, Union{<:IOExample, Nothing}}
    output = nothing

    for example ∈ problem.spec
        try
            output = execute_on_input(symboltable, expr, example.in)
            if (output != example.out)
                return (output, failed, example)
            end
        catch e
            return (nothing, crashed, example)
        end
    end

    return (output, success, nothing)
end

"""
    evaluate(
        program::AbstractRuleNode,
        problem::Problem{<:AbstractVector{<:IOExample}},
        grammar_tags::Dict{Int, Any},
        interpret::Union{Function, Nothing} = nothing
    )::Tuple{Union{Any, Nothing}, EvalResult, Union{<:IOExample, Nothing}}

Evaluate the program on the examples using a custom interpret function if provided.
"""
function evaluate(
    program::AbstractRuleNode,
    problem::Problem{<:AbstractVector{<:IOExample}},
    grammar_tags::Dict{Int, Any},
    interpret::Union{Function, Nothing} = nothing
)::Tuple{Union{Any, Nothing}, EvalResult, Union{<:IOExample, Nothing}}
    output = nothing

    for example ∈ problem.spec
        try
            output = execute_on_input(program, grammar_tags, example.in, interpret)
            if (output != example.out)
                return (output, failed, example)
            end
        catch e
            return (nothing, crashed, example)
        end
    end

    return (output, success, nothing)
end

end # module
