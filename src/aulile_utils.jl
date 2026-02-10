"""
    AulileStats

    Holds statistics returned from the aulile search process.

    - `program`::RuleNode: The best program found.
    - `score`::Number: The score of the best program attained.
    - `iterations::Int`: The number of iterations performed during the search.
    - `enumerations::Int`: The number of enumerations performed during the search.
"""
struct AulileStats
    program::RuleNode
    score::Number
    iterations::Int
    enumerations::Int
end

"""
    SearchStats

    Holds statistics returned from the search process.

    - `programs`::Vector{RuleNode}: Best programs found, sorted from best to worst.
    - `iter_state`: Iterator state after the search.
    - `score`::Number: Best score found.
    - `enumerations::Int`: The number of enumerations performed during the search.
"""
struct SearchStats
    programs::Vector{RuleNode}
    iter_state::Any
    score::Number
    enumerations::Int
    time::Float64
    exhausted_start::Bool
end


"""
    Default interpreter implementation that follows the execute_on_input pattern.
    This is used when no custom interpreter is provided to synth_with_aux.
"""
function default_interpreter(program::Any, grammar::AbstractGrammar, example::IOExample, _)
    # Convert the program to an expression if it's a RuleNode
    expr = program isa AbstractRuleNode ? rulenode2expr(program, grammar) : program
    symboltable = grammar2symboltable(grammar)
    return execute_on_input(symboltable, expr, example.in)
end


"""
    Prints the new grammar rules added after a specific point in the grammar.

    - `grammar::AbstractGrammar`: The grammar object containing rules and types.
    - `init_grammar_size::Int`: The initial size of the grammar before new rules were added.
"""
function print_new_grammar_rules(grammar::AbstractGrammar, init_grammar_size::Int)
    println("{...}")
    for i in init_grammar_size+1:length(grammar.rules)
        println(i, ": ", grammar.types[i], " = ", grammar.rules[i])
    end
    println()
end

"""
    A wrapper struct for auxiliary evaluation functions used in the Aulile learning loop.

    - `func`: A function that returns a score based on an `IOExample` and the candidate output.
    - `initial_score`: A function that returns initial score based on `Problem`.
    - `best_value`: The target score the synthesizer attempts to minimize. When a program achieves this score across all examples, 
        it is considered optimal.
"""
struct AuxFunction
    func::Function
    initial_score::Function
    best_value::Number # NOTE: Aulile tries to *minimize* to this value
end

# Make `AuxFunction` behave like a regular callable function.
function (af::AuxFunction)(example::IOExample, output)
    return af.func(example, output)
end

"""
    Default auxiliary function of just checking how many tests are correct.
"""
default_aux = AuxFunction(
    (expected::IOExample{<:Any,<:Any}, actual::Any) -> begin
        if expected.out == actual
            return 0
        else
            return 1
        end
    end,
    problem::Problem -> length(problem.spec),
    0
)

"""
    A wrapper struct for evaluation arguments

    - `aux`: An `AuxFunction` used to compute the score between expected and actual output.
    - `interpret`: Interpreter function for program evaluation (defaults to `default_interpreter`).
    - `allow_evaluation_errors`: Whether evaluation errors should be tolerated or raise an exception.
"""
Base.@kwdef struct EvaluateOptions
    problem::Problem{<:AbstractVector{<:IOExample}}

    aux::AuxFunction=default_aux
    interpret::Function=default_interpreter
    allow_evaluation_errors::Bool=false
end

"""
    A wrapper struct for synth arguments

    - `num_returned_programs`: Number of best programs returned.
    - `max_enumerations`: Maximum number of candidate programs to try.
    - `max_time`: Maximum allowed runtime for the synthesis loop.
    - `print_debug`: If true, print debug output.
    - `eval_opts`: Options for evaluation.
"""
Base.@kwdef struct SynthOptions
    evaluateOptions::EvaluateOptions

    num_returned_programs=1
    max_enumerations=typemax(Int)
    max_time=typemax(Float64)
    print_debug=false
end

"""
    A wrapper struct for Aulile arguments

    - `max_iterations`: Maximum number of learning iterations to perform.
    - `max_depth`: Maximum depth for program enumeration.
    - `print_debug`: Whether to print debug info.
    - `synth_opts`: Options for synthesis.
"""
Base.@kwdef struct AulileOptions
    synthOptions::SynthOptions

    max_iterations=10000
    max_depth=10
    restart_iterator=true
end


"""
    Turns a max heap into a vector (best-to-worst order).
    Also returns the best found score.

    - `heap`: The heap containing the best programs, ordered from worst to best
"""
function heap_to_vec(heap::BinaryHeap{Tuple{Int,RuleNode}})::Tuple{Vector{RuleNode},Int}
    top_programs = Vector{RuleNode}()
    best_found_score = typemax(Int)
    while !isempty(heap)
        score, program = pop!(heap)
        push!(top_programs, program)
        best_found_score = score
    end
    reverse!(top_programs)
    return top_programs, best_found_score
end