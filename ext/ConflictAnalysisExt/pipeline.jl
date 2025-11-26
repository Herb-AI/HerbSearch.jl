struct ConflictContext
    grammar::AbstractGrammar
    symboltable::SymbolTable
    candidate::AbstractRuleNode
    output::Any
    counter_example::IOExample
end

"""
    run_conflict_pipeline(techniques::Vector{<:AbstractConflictTechnique})

Run each conflict analysis technique in parallel by first calling `check_conflict`,
and if a conflict is found, calls `analyze_conflict`. Collects and returns all
resulting `AbstractConflictConstraint` objects in a thread-safe manner.
"""
function run_conflict_pipeline(techniques::Vector{<:AbstractConflictTechnique}, ctx::ConflictContext)
    constraints = AbstractConflictConstraint[]
    grammar_constraints = AbstractConflictConstraint[]

    for tech in techniques
        autoinput!(tech, ctx)

        tech.data = check_conflict(tech)
        if isnothing(tech.data) 
            continue
        end

        analyze_result = analyze_conflict(tech)
        if isnothing(analyze_result)
            continue
        end

        if analyze_result isa AbstractConflictConstraint
            if analyze_result.add_to_grammar
                push!(grammar_constraints, analyze_result)
            else
                push!(constraints, analyze_result)
            end
        elseif analyze_result isa AbstractVector
            for c in analyze_result
                if c isa AbstractConflictConstraint
                    if c.add_to_grammar 
                        push!(grammar_constraints, c)
                    else
                        push!(constraints, c)
                    end
                end
            end
        else
            # Consider logging this or handling more gracefully
            @error "analyze_conflict returned unsupported type: $(typeof(analyze_result))"
        end
    end
    return constraints, grammar_constraints
end


"""
    build_techniques(names::Vector{Symbol}) -> Vector{AbstractConflictTechnique}

Instantiate techniques once, based on a simple list of symbols.
"""
function build_techniques(names::Vector{Symbol})
    techs = AbstractConflictTechnique[]
    for nm in names
        nm === :MUC  && push!(techs, MUC())
        nm === :ERA  && push!(techs, ERA())
        nm === :SeAn && push!(techs, SeAn())
    end
    return techs
end

autoinput!(tech::MUC,  ctx::ConflictContext) = (tech.input = MUCInput(ctx.candidate, ctx.grammar, ctx.counter_example))
autoinput!(tech::ERA,  ctx::ConflictContext) = (tech.input = ERAInput(ctx.candidate, ctx.grammar, ctx.output))
autoinput!(tech::SeAn, ctx::ConflictContext) = (tech.input = SeAnInput(ctx.candidate, ctx.grammar, ctx.symboltable, ctx.counter_example))

autoinput!(::AbstractConflictTechnique, ::ConflictContext) = nothing