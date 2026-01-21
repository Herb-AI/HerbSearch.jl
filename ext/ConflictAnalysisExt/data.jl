abstract type AbstractConflictTechnique end

"Generic input data for conflict analysis, used by check_conflict"
abstract type AbstractConflictInput end

struct MUCInput <: AbstractConflictInput
    root::AbstractRuleNode
    grammar::AbstractGrammar
    counter_example::IOExample
end

struct ERAInput <: AbstractConflictInput
    root::AbstractRuleNode
    grammar::AbstractGrammar
    evaluation::Union{Any, Nothing}
end

struct SeAnInput <: AbstractConflictInput
    root::AbstractRuleNode
    grammar::AbstractGrammar
    symboltable::SymbolTable
    counter_example::IOExample
end

"Generic conflict data returned by check_conflict, used by analyse_conflict"
abstract type AbstractConflictData end

struct UnsatCoreData <: AbstractConflictData
    core_constraints_map::Dict{Int, Vector{Tuple{Any, String, Any}}}
end

struct ERAException <: AbstractConflictData
    program::AbstractRuleNode
end

struct ERARedundantValues <: AbstractConflictData
    program::AbstractRuleNode
    value::Any
end

struct SeAnData <: AbstractConflictData
    semantics::Vector{Expr}
end

"Generic conflict constraint returned by analyse_conflict"
abstract type AbstractConflictConstraint end

struct MUCConstraint <: AbstractConflictConstraint
    cons::Forbidden
    origin::String
    add_to_grammar::Bool
end

function MUCConstraint(cons::Forbidden, origin::String)
    return MUCConstraint(cons, origin, false)
end

struct ERAConstraint <: AbstractConflictConstraint
    cons::Forbidden
    origin::String
    add_to_grammar::Bool
end

function ERAConstraint(cons::Forbidden, origin::String)
    return ERAConstraint(cons, origin, true)
end

struct SeAnConstraint <: AbstractConflictConstraint
    cons::Forbidden
    origin::String
    add_to_grammar::Bool
end

function SeAnConstraint(cons::Forbidden, origin::String)
    return SeAnConstraint(cons, origin, false)
end
