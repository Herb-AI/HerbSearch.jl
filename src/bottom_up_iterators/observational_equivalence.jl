

struct ObservationalEquivalenceChecker
    seen_hashes::Set{UInt64}
end

function ObservationalEquivalenceChecker()
    return ObservationalEquivalenceChecker(Set{UInt64}())
end

function is_new_program!(
    checker::ObservationalEquivalenceChecker,
    program::RuleNode,
    grammar::ContextSensitiveGrammar,
    problem::Any # TODO: define a specific type for this
)::Bool
    try
        outputs = [execute_on_input(grammar, program, example.in) for example in problem.spec]
        hash_value = hash(outputs)
        if hash_value in checker.seen_hashes
            return false 
        end
        push!(checker.seen_hashes, hash_value)
        return true
    catch e
        return false
    end
end