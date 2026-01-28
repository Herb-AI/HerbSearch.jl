

using HerbCore
using HerbSpecification
using HerbGrammar
using MLStyle

using HerbBenchmarks
using HerbBenchmarks.PBE_SLIA_Track_2019
using HerbBenchmarks: get_relevant_tags



struct EvaluationError <: Exception
    prog::Any
    input::Dict{Symbol, Any}
    error::Exception
end

Base.showerror(io::IO, e::EvaluationError) = begin
    print(io, "Error while evaluating program:\n")
    print(io, e.prog)
    print(io, "\nInput: ", e.input)
    print(io, "\nError: ", e.error)
end

"""
    evaluate(problem::Problem{Vector{IOExample}}, expr::Any, tab::SymbolTable; allow_evaluation_errors::Bool=false)

Evaluate the expression on the examples.

Optional parameters:

    - `shortcircuit` - Whether to stop evaluating after finding single example fails, to speed up the [synth](@ref) procedure. If true, the returned score is an underapproximation of the actual score.
    - `allow_evaluation_errors` - Whether the search should continue if an exception is thrown in the evaluation or throw the error

Returns a score in the interval [0, 1]
"""
function evaluate(
    problem::Problem{<:AbstractVector{<:IOExample}},
    expr::Any,
    symboltable::SymbolTable;
    shortcircuit::Bool=true,
    allow_evaluation_errors::Bool=false
)::Number
    number_of_satisfied_examples = 0

    crashed = false
    for example ∈ problem.spec
        try
            output = execute_on_input(symboltable, expr, example.in)
            if (output == example.out)
                number_of_satisfied_examples += 1
            elseif (shortcircuit)
                break;
            end
        catch e
            # You could also decide to handle less severe errors (such as index out of range) differently,
            # for example by just increasing the error value and keeping the program as a candidate.
            crashed = true
            # Throw the error again if evaluation errors aren't allowed
            eval_error = EvaluationError(expr, example.in, e)
            allow_evaluation_errors || throw(eval_error)
            break
        end
    end

    return number_of_satisfied_examples/length(problem.spec);
end

function evaluate_with_mask(
    problem::Problem{<:AbstractVector{<:IOExample}},
    expr::Any,
    symboltable::SymbolTable;
    shortcircuit::Bool = true,
    allow_evaluation_errors::Bool = false
)::Tuple{Float64, UInt64}

    n = length(problem.spec)
    mask::UInt64 = 0x0
    satisfied = 0


    for (i, example) in enumerate(problem.spec)
        bit_pos = UInt64(1) << (i - 1)

        try
            output = execute_on_input(symboltable, expr, example.in)

            if output == example.out
                mask |= bit_pos
                satisfied += 1
            elseif shortcircuit
                break
            end

        catch e
            eval_error = EvaluationError(expr, example.in, e)
            allow_evaluation_errors || throw(eval_error)
            break
        end
    end

    return satisfied / n, mask
end


function interpret_sygus_fn(
    prog::AbstractRuleNode,
    grammar_tags::Dict{Int,Any},
    input::Dict{Symbol,Any}
)
    r = HerbCore.get_rule(prog)
    c = HerbCore.get_children(prog)

    MLStyle.@match grammar_tags[r] begin
        # ---------- String operations ----------
        :concat_cvc =>
            concat_cvc(
                interpret_sygus_fn(c[1], grammar_tags, input),
                interpret_sygus_fn(c[2], grammar_tags, input)
            )

        :replace_cvc =>
            replace_cvc(
                interpret_sygus_fn(c[1], grammar_tags, input),
                interpret_sygus_fn(c[2], grammar_tags, input),
                interpret_sygus_fn(c[3], grammar_tags, input)
            )

        :at_cvc =>
            at_cvc(
                interpret_sygus_fn(c[1], grammar_tags, input),
                interpret_sygus_fn(c[2], grammar_tags, input)
            )

        :int_to_str_cvc =>
            int_to_str_cvc(
                interpret_sygus_fn(c[1], grammar_tags, input)
            )

        :substr_cvc =>
            substr_cvc(
                interpret_sygus_fn(c[1], grammar_tags, input),
                interpret_sygus_fn(c[2], grammar_tags, input),
                interpret_sygus_fn(c[3], grammar_tags, input)
            )

        :len_cvc =>
            len_cvc(
                interpret_sygus_fn(c[1], grammar_tags, input)
            )

        :str_to_int_cvc =>
            str_to_int_cvc(
                interpret_sygus_fn(c[1], grammar_tags, input)
            )

        :indexof_cvc =>
            indexof_cvc(
                interpret_sygus_fn(c[1], grammar_tags, input),
                interpret_sygus_fn(c[2], grammar_tags, input),
                interpret_sygus_fn(c[3], grammar_tags, input)
            )

        :prefixof_cvc =>
            prefixof_cvc(
                interpret_sygus_fn(c[1], grammar_tags, input),
                interpret_sygus_fn(c[2], grammar_tags, input)
            )

        :suffixof_cvc =>
            suffixof_cvc(
                interpret_sygus_fn(c[1], grammar_tags, input),
                interpret_sygus_fn(c[2], grammar_tags, input)
            )

        :contains_cvc =>
            contains_cvc(
                interpret_sygus_fn(c[1], grammar_tags, input),
                interpret_sygus_fn(c[2], grammar_tags, input)
            )

        # ---------- Arithmetic / boolean ----------
        :+ =>
            interpret_sygus_fn(c[1], grammar_tags, input) +
            interpret_sygus_fn(c[2], grammar_tags, input)

        :- =>
            interpret_sygus_fn(c[1], grammar_tags, input) -
            interpret_sygus_fn(c[2], grammar_tags, input)

        :(==) =>
            interpret_sygus_fn(c[1], grammar_tags, input) ==
            interpret_sygus_fn(c[2], grammar_tags, input)

        :IF =>
            interpret_sygus_fn(c[1], grammar_tags, input) ?
                interpret_sygus_fn(c[2], grammar_tags, input) :
                interpret_sygus_fn(c[3], grammar_tags, input)

        # ---------- Literals / variables ----------
        _ => begin
            tag = grammar_tags[r]

            if tag isa Symbol && occursin("_arg_", String(tag))
                return get(input, tag, nothing)
            else
                return tag
            end
        end
    end
end

function evaluate_sygus_with_mask(
    problem::Problem{<:AbstractVector{<:IOExample}},
    prog::AbstractRuleNode,
    grammar_tags;
    shortcircuit::Bool = true,
    allow_evaluation_errors::Bool = false
)::Tuple{Float64, UInt64}

    n = length(problem.spec)
    mask::UInt64 = 0x0
    satisfied = 0


    for (i, example) in enumerate(problem.spec)
        bit_pos = UInt64(1) << (i - 1)

        try
            output = interpret_sygus_fn(prog, grammar_tags, example.in)

            if output == example.out
                mask |= bit_pos
                satisfied += 1
            elseif shortcircuit
                break
            end

        catch e
            eval_error = EvaluationError(prog, example.in, e)
            allow_evaluation_errors || throw(eval_error)
            break
        end
    end

    return satisfied / n, mask
end



