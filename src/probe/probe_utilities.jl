"""
    struct ProgramCache 

Stores the evaluation cost and the program in a structure.
This should go away ... :P
"""
mutable struct ProgramCache
    program::RuleNode
    correct_examples::Vector{Int}
    cost::Int
end
function Base.:(==)(a::ProgramCache, b::ProgramCache)
    return a.program == b.program
end
Base.hash(a::ProgramCache) = hash(a.program)

"""
    evaluate_program(program::AbstractRuleNode, grammar::AbstractGrammar, examples::Vector{<:IOExample}, symboltable::SymbolTable)

Evaluates a program using the given examples and returns a tuple of two things:
- an array that stores for each example the evaluation output.
- an array that stores the indices of the examples that were correctly passed.
"""
function evaluate_program(program::AbstractRuleNode, grammar::AbstractGrammar, examples::Vector{<:IOExample}, symboltable::SymbolTable)
    correct_examples = Vector{Int}()
    eval_observation = []
    expr = rulenode2expr(program, grammar)
    for (example_index, example) ∈ enumerate(examples)
        try
            output = execute_on_input(symboltable, expr, example.in)
            push!(eval_observation, output)

            if output == example.out
                push!(correct_examples, example_index)
            end
        catch e
            if isa(e, MethodError)
                println("$expr\t$example\t$e")
            end
            continue
        end
    end
    return eval_observation, correct_examples
end
