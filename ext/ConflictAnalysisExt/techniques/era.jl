include("../utils/era_utils.jl")

mutable struct ERA <: AbstractConflictTechnique
    input::Union{ERAInput, Nothing}
    data::Union{ERAException, ERARedundantValues, Nothing}
    max_constraint_size::Int64
end

function ERA()
    return ERA(nothing, nothing, 4)
end

function check_conflict(technique::ERA)
    program = technique.input.root.children[1] # TODO: Generalize for program structures with and without a start symbol.
    if (length(program) > technique.max_constraint_size)
        return nothing
    end

    if isnothing(technique.input.evaluation)
        return ERAException(program)
    elseif length(program) > 1 && technique.input.evaluation isa String && technique.input.evaluation in get_terminals(technique.input.grammar)
        return ERARedundantValues(program, technique.input.evaluation)
    elseif technique.input.evaluation isa Array && isempty(technique.input.evaluation)
        return ERARedundantValues(program, technique.input.evaluation)
    else
        return nothing
    end
    return nothing
end

function analyze_conflict(technique::ERA)
    if technique.data isa ERARedundantValues
        return ERAConstraint(Forbidden(freeze_state(technique.data.program)), "ERA Redundant Value: $(technique.data.value)")
    elseif technique.data isa ERAException
        return ERAConstraint(Forbidden(freeze_state(technique.data.program)), "ERA Exception")
    end
end