struct ObservationalEquivalenceChecker{T <: AbstractRuleNode}
    seen_hashes::Set{UInt64}
end

function ObservationalEquivalenceChecker{T}() where T
    return ObservationalEquivalenceChecker{T}(Set{UInt64}())
end

function is_new_program!(
    checker::ObservationalEquivalenceChecker{RuleNode},
    program::RuleNode,
    grammar::ContextSensitiveGrammar,
    spec::Any # TODO: define a specific type for this
)::Bool
    try
        outputs = [execute_on_input(grammar, program, example.in) for example in spec]
        hash_value = hash(outputs)
        if hash_value in checker.seen_hashes
            return false 
        end
        push!(checker.seen_hashes, hash_value)
        return true
    catch _
        return false
    end
end

is_new_program!(
    ::ObservationalEquivalenceChecker{UniformHole},
    ::RuleNode,
    ::ContextSensitiveGrammar,
    ::Any
)::Bool = true