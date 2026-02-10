"""
    AulileStats

    Holds statistics about the aulile search process.

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

    Holds statistics about a search process.

    - `programs`::Vector{RuleNode}: Best programs found, sorted from best to worst.
    - `iter_state`: Iterator state after the search.
    - `score`::Number: Best score found.
    - `enumerations::Int`: The number of enumerations performed during the search.
    - `exhausted_start::Bool`: Whether the iterator was fully exhausted at the start of this search. 
        NOTE: This is a workaround due to the fact that we cannot directly check iterator's exhaustion without consumption.
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
    default_interpreter(program::Any, grammar::AbstractGrammar, example::IOExample, _)

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
    print_new_grammar_rules(grammar::AbstractGrammar, init_grammar_size::Int)

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
	AuxFunction(func::Function, initial_score::Function, best_value::Number)

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
    Turns a max heap into a vector (best-to-worst order).
    Also returns the best found score.

    - `heap`: The heap containing the best programs, ordered from worst to best
"""
function heap_to_vec(heap::BinaryHeap{Tuple{Int,RuleNode}})::Tuple{Vector{RuleNode}, Int}
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