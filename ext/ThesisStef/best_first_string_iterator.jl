using DataStructures

struct ProgramEntry
    program
    cost
    states
    parent
end

struct BestFirstStringIterator
    heuristic::Function
    max_size::Int
    explored_programs::Vector{Any}
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

function BestFirstStringIterator(heuristic, max_size, problem_id, example_ids)
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
    start_states = [example.in[:_arg_1] for example in examples]

    return BestFirstStringIterator(
        heuristic,
        max_size,
        [],
        problem_id,
        example_ids,
        benchmark,
        problem,
        examples,
        start_states,
        [example.out for example in examples],
        string_grammar,
        Set([start_states]),
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
    parent,
)
    for program in programs
        if length(program) > iter.max_size
            continue
        end

        push!(iter.explored_programs, program)

        states = interpret_program(iter, program)

        if isnothing(states) || states in iter.seen_statess
            continue
        end

        push!(iter.seen_statess, states)
        cost = iter.heuristic(iter, program, states)

        if cost != Inf
            entry = ProgramEntry(program, cost, states, parent)
            enqueue!(queue, entry, cost)
        end
    end
end

function initialize!(
    iter::BestFirstStringIterator, 
    queue,#::PriorityQueue{Any, Number}, 
)
    programs = [RuleNode(r, []) for r in 3:7]
    empty_program_entry = ProgramEntry(nothing, nothing, iter.start_states, nothing)
    add_to_queue!(iter, queue, programs, empty_program_entry)
end

function expand!(
    iter::BestFirstStringIterator, 
    queue,#::PriorityQueue{Any, Number}, 
    entry,#::AbstractRuleNode,
)   
    program = entry.program

    programs = []
    append!(programs, [RuleNode(2, [program, p]) for p in iter.explored_programs])
    append!(programs, [RuleNode(2, [p, program]) for p in iter.explored_programs])
    append!(programs, [RuleNode(8, [RuleNode(c, []), program, p]) for p in iter.explored_programs for c in 10:19])
    append!(programs, [RuleNode(9, [RuleNode(c, []), program]) for c in 10:19])

    # if "$program" == "2{9{15,7},3}"
    #     println("aaaaa")
    #     println(length(program))
    #     @show programs
    # end

    add_to_queue!(iter, queue, programs, entry)
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
    entry = dequeue!(queue)
    expand!(iter, queue, entry)

    if length(queue) == 0
        return nothing
    end

    # @show queue

    return entry, queue
end