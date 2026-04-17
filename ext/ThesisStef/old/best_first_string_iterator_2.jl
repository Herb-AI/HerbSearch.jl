using DataStructures

struct BestFirstStringIterator
    heuristic::Function
    problem_id::Int
    example_ids::Vector{Int}
    benchmark
    problem
    examples
    start_states
    final_states
    grammar
    seen_statess
end

struct ProgramEntry
    program
    cost
    states
end

function BestFirstStringIterator(heuristic, problem_id, example_ids)
    string_grammar = @HerbGrammar.cfgrammar begin
                # 1         # 2
        Program = Operation | (Program; Operation)

                    # 3           # 4          # 5               # 6               # 7      # 8                               # 9  
        Operation = moveRight() | moveLeft() | makeUppercase() | makeLowercase() | drop() | IF(Condition, Program, Program) | WHILE(Condition, Program)

                    # 10      # 11         # 12        # 13           # 14         # 15            # 16            # 17               # 18            # 19               # 20         # 21           # 22        # 23
        Condition = atEnd() | notAtEnd() | atStart() | notAtStart() | isLetter() | isNotLetter() | isUppercase() | isNotUppercase() | isLowercase() | isNotLowercase() | isNumber() | isNotNumber() | isSpace() | isNotSpace()
    end

    benchmark = HerbBenchmarks.String_transformations_2020
    problem   = get_all_problem_grammar_pairs(benchmark)[problem_id].problem
    examples  = problem.spec[example_ids]

    return BestFirstStringIterator(
        heuristic,
        problem_id,
        example_ids,
        benchmark,
        problem,
        examples,
        [example.in[:_arg_1] for example in examples],
        [example.out for example in examples],
        string_grammar,
        Set(),
    )
end

function interpret_program(iter::BestFirstStringIterator, program)
    try
        return [iter.benchmark.interpret(program, iter.benchmark.get_relevant_tags(iter.grammar), example.in[:_arg_1]) for example in iter.examples]
    catch e
        if typeof(e) == BoundsError
            return nothing
        else
            rethrow(e)
        end
    end
end

function add_to_queue!(
    iter::BestFirstStringIterator, 
    queue,#::PriorityQueue{Any, Number}, 
    programs,#::Vector{Any},
    parent,#::Union{AbstractRuleNode, Nothing},
    grand_parent,#::Union{AbstractRuleNode, Nothing},
)
    for program in programs
        states = interpret_program(iter, program)

        if isnothing(states) || states in iter.seen_statess
            continue
        end

        push!(iter.seen_statess, states)
        cost = iter.heuristic(iter, program, states)

        if cost != Inf
            current = ProgramEntry(program, cost, states)

            enqueue!(queue, (current, parent, grand_parent), cost)
        end
    end
end

function initialize!(
    iter::BestFirstStringIterator, 
    queue,#::PriorityQueue{Any, Number}, 
)
    programs = [RuleNode(r, []) for r in 3:7]
    empty_program = ProgramEntry(nothing, Inf, iter.start_states)
    add_to_queue!(iter, queue, programs, empty_program, empty_program)
end

function expand!(
    iter::BestFirstStringIterator, 
    queue,#::PriorityQueue{Any, Number}, 
    current,#::AbstractRuleNode, 
    parent,#::Union{AbstractRuleNode, Nothing}
)   
    program = current.program
    programs = []
    append!(programs, [RuleNode(2, [program, RuleNode(r, [])]) for r in 3:7])
    append!(programs, [RuleNode(8, [RuleNode(c, []), program, RuleNode(r, [])]) for r in 3:7 for c in 10:19])
    append!(programs, [RuleNode(9, [RuleNode(c, []), program]) for c in 10:19])
    add_to_queue!(iter, queue, programs, current, parent)
end

function Base.iterate(iter::BestFirstStringIterator)
    queue = PriorityQueue{Any, Number}()
    initialize!(iter, queue)

    return Base.iterate(iter, queue)
end

function Base.iterate(
    iter::BestFirstStringIterator, 
    queue,#::PriorityQueue{Any, Number}, 
)
    (current, parent, grand_parent) = dequeue!(queue)
    expand!(iter, queue, current, parent)

    if length(queue) == 0
        return nothing
    end

    return (current, parent, grand_parent), queue
end