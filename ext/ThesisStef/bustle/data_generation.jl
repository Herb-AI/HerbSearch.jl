using HerbCore, HerbGrammar, HerbConstraints, HerbBenchmarks, HerbSearch, HerbSpecification
using MLStyle

include("string_domain.jl")
include("property_signature.jl")


#=

repeat 1000 times:
    I <- generate random inputs

    F <- run bottom-up search from I without target returning all generated expressions

    repeat 100 times:
        f <- select random expression
        O <- execute f on I

        f_p <- select random subexpression from f
        V_p <- execute f_p on I
        add training example (I, V_p, O) -> 1

        f_n <- select random subexpression from F that is no subexpression of f
        V_n <- execute f_n on I
        add training example (I, V_n, O) -> 0

What I do differently
 - Grammar only contains integers 1 to 30, in stead of 1 to 99

What they did not specify (check if TF-coder does):
 - Amount of inputs per search
 - How to generate a random string
 - Amount of expressions created with bottom-up search
 - Use of observational equivalance with bottom-up search
=#

function generate_training_data_observation_equivalence(; n_inputs_per_search = 5, n_searches = 1000, n_expressions_per_search = 5000, n_selections = 100)
    training_examples = []

    # Constraint to use the last rule, which is the argument rule
    rule_index = length(string_grammar.rules)
    addconstraint!(string_grammar, Contains(rule_index))
    grammar_tags = get_relevant_tags(string_grammar)

    # Perform n (= 1000) searches
    for _ in 1:n_searches

        # For each search, generate n (= ?) random input strings
        inputs = [generate_random_string() for _ in 1:n_inputs_per_search]

        # @show inputs
        # From these input strings, perform bottom-up search without target to generate n (= ?) expression
        expressions_and_outputs = generate_expressions_with_outputs(inputs, n_expressions_per_search, grammar_tags)

        # Perform n (= 100) selections
        for _ in 1:n_selections

            # Select a random expression that contains a valid subexpression
            expression, output = rand(expressions_and_outputs)
            subexpressions = all_subexpressions(expression)
            while length(subexpressions) == 0
                expression, output = rand(expressions_and_outputs)
                subexpressions = all_subexpressions(expression)
            end

            # @show expression, output

            # Select a random subexpression and execute on inputs
            subexpression = rand(subexpressions) 
            intermediate_output = execute_expression(subexpression, grammar_tags, inputs) 

            # @show subexpression, intermediate_output

            # Select a random expression that is not a subexpression and execute on inputs
            non_subexpression, non_intermediate_output = nothing, nothing
            while isnothing(non_subexpression)
                non_subexpression_candidate, non_intermediate_output_candidate = rand(expressions_and_outputs)

                if !is_subexpression(expression, non_subexpression_candidate)
                    non_subexpression, non_intermediate_output = non_subexpression_candidate, non_intermediate_output_candidate
                end
            end

            # @show non_subexpression, non_intermediate_output

            # @show inputs
            # println()

            # @show rulenode2expr(expression, string_grammar)
            # @show output
            # println()

            # @show rulenode2expr(subexpression, string_grammar)
            # @show intermediate_output
            # println()

            # @show rulenode2expr(non_subexpression, string_grammar)
            # @show non_intermediate_output
            # println()

            positive_sign = sign_ternary(inputs, intermediate_output, output)
            negative_sign = sign_ternary(inputs, non_intermediate_output, output)

            # @show positive_sign
            # @show negative_sign

            # Add positive and negative training examples
            positive_training_example = (positive_sign, 1)
            negative_training_example = (negative_sign, 0)
            push!(training_examples, positive_training_example)
            push!(training_examples, negative_training_example)
        end
    end

    return training_examples
end

function generate_training_data_no_observation_equivalence(; n_inputs_per_search = 5, n_searches = 1000, n_expressions_per_search = 5000, n_selections = 100)::Vector{Tuple{Vector{Number},Number}}
    training_examples = []

    rule_index = length(string_grammar.rules)
    addconstraint!(string_grammar, Contains(rule_index))
    grammar_tags = get_relevant_tags(string_grammar)

    # From these input strings, perform bottom-up search without target to generate n (= ?) expression
    expressions = generate_expressions(n_expressions_per_search)

    # Perform n (= 1000) searches
    for n in 1:n_searches
        @show n

        # For each search, generate n (= ?) random input strings
        inputs = [generate_random_string() for _ in 1:n_inputs_per_search]

        # Perform n (= 100) selections
        for _ in 1:n_selections

            # Select a random expression that contains a valid subexpression
            subexpressions = []
            expression = nothing
            outputs = nothing

            while length(subexpressions) == 0
                expression = rand(expressions)
                outputs = execute_expression(expression, grammar_tags, inputs)

                if isnothing(outputs)
                    # println("Failed expression")
                    continue
                end

                subexpressions = all_subexpressions(expression)
            end

            # @show expression, output

            # Select a random subexpression and execute on inputs
            subexpression = rand(subexpressions)
            intermediate_output = execute_expression(subexpression, grammar_tags, inputs)

            # @show subexpression, intermediate_output

            # Select a random expression that is not a subexpression and execute on inputs
            non_subexpression = nothing
            non_intermediate_output = nothing
            while isnothing(non_subexpression)
                non_subexpression_candidate = rand(expressions)

                if is_subexpression(expression, non_subexpression_candidate)
                    # println("Subexpression not sub")
                    continue
                end

                non_intermediate_output_candidate = execute_expression(non_subexpression_candidate, grammar_tags, inputs)

                if isnothing(non_intermediate_output_candidate)
                    # println("Invalid subexpression")
                    continue
                end

                
                non_subexpression, non_intermediate_output = non_subexpression_candidate, non_intermediate_output_candidate
            end

            # @show non_subexpression, non_intermediate_output

            positive_sign = sign_ternary(inputs, intermediate_output, outputs)
            negative_sign = sign_ternary(inputs, non_intermediate_output, outputs)

            # Add positive and negative training examples
            positive_training_example = (positive_sign, 1)
            negative_training_example = (negative_sign, 0)
            push!(training_examples, positive_training_example)
            push!(training_examples, negative_training_example)
        end
    end

    return training_examples
end

function generate_random_string()::String
    # Actual process unknown
    # My implementation: generate random string of size between 10 and 30 (uniformly drawn) with characters a-Z, 0-9, and symbols from grammar

    alphabet = vcat(
        collect('a':'z'),
        collect('A':'Z'),
        collect('0':'9'),
        ["", " ", ",", ".", "!", "?", "(", ")", "[", "]", "<", ">", "{", "}", "-", "+", "_", "/", "\$", "#", ":", ";", "@", "%", "0"]
    )
    size = rand(10:30)

    return join(rand(alphabet, size), "")
end

function generate_expressions_with_outputs(input_strings::Vector{String}, n_expressions::Int, grammar_tags::Dict{Int,Any})::Vector{Tuple{AbstractRuleNode,Vector{String}}}
    # Amount unknown
    # Usage of observational equivalance unknown
    # My implementation: return the first n (= 5000) expressions using observational equivalance

    iterator = BFSIterator(string_grammar, :String)

    expressions = []
    outputs = []

    for expression in iterator
        output = execute_expression(expression, grammar_tags, input_strings)

        if isnothing(output) || output in outputs
            continue
        end

        push!(expressions, deepcopy(expression))
        push!(outputs, output)

        if length(expressions) >= n_expressions
            break
        end
    end

    return collect(zip(expressions, outputs))
end

function generate_expressions(n_expressions::Int)::Vector{AbstractRuleNode}
    # Amount unknown
    # My implementation: return the first n (= 5000) expressions without observational equivalance

    iterator = BFSIterator(string_grammar, :String)

    expressions = []
    
    for expression in iterator
        if length(expressions) >= n_expressions
            break
        end

        push!(expressions, deepcopy(expression))
    end

    return expressions
end

function execute_expression(expression::AbstractRuleNode, grammar_tags::Dict{Int,Any}, inputs::Vector{String})::Union{Nothing,Vector{String}}
    outputs = []

    for input in inputs
        try
            output = interpret_string(expression, grammar_tags, input)
            push!(outputs, output)
        catch e
            if e isa BoundsError || e isa ArgumentError || e isa MethodError
                return nothing
            else
                rethrow(e)
            end
        end
    end
    
    return outputs
end

function all_subexpressions(expression::AbstractRuleNode)::Vector{AbstractRuleNode}
    subexpressions = [child for child in get_children(expression) if string_grammar.types[get_rule(child)] == :String]

    for c in get_children(expression)
        subexpressions = vcat(subexpressions, all_subexpressions(c))
    end

    return subexpressions
end

function is_subexpression(expression::AbstractRuleNode, subexpression_candidate::AbstractRuleNode)::Bool
    if expression == subexpression_candidate
        return true
    end

    return any([is_subexpression(c, subexpression_candidate) for c in get_children(expression)])
end


# generate_training_data_no_observation_equivalence(
#     n_inputs_per_search = 5, 
#     n_searches = 1000,
#     n_expressions_per_search = 100_000, 
#     n_selections = 100
# )

# generate_training_data_observation_equivalence(
#     n_inputs_per_search = 5, 
#     n_searches = 1000,
#     n_expressions_per_search = 5000, 
#     n_selections = 100,
# )