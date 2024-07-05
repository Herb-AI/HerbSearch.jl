"""
    evaluate_program(program::RuleNode, grammar::AbstractGrammar, examples::Vector{<:IOExample}, symboltable::SymbolTable)

Evaluates a program using the given examples and returns a tuple of two things:
- an array that stores for each example the evaluation output.
- an array that stores the indices of the examples that were correctly passed.
"""
function evaluate_program(program::RuleNode, grammar::AbstractGrammar, examples::Vector{<:IOExample}, symboltable::SymbolTable)
    correct_examples = Vector{Int}()
    eval_observation = []
    expr = rulenode2expr(program, grammar)
    for (example_index, example) ∈ enumerate(examples)
        output = execute_on_input(symboltable, expr, example.in)
        push!(eval_observation, output)

        if output == example.out
            push!(correct_examples, example_index)
        end
    end
    return eval_observation, correct_examples
end
