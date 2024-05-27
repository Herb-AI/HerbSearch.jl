
"""
    generic_run(enumerator::Function, stopping_condition::Function, max_depth::Int, problem::Problem, grammar::ContextSensitiveGrammar;  start_program::Union{Nothing,RuleNode} = nothing)

Runs an simple vanilla search algorithm represented by an enumerator until the stopping condition is met. 
It uses [`HerbSearch.supervised_search`](@ref) to run the enumerator and monitor the stopping condition.

Returns a tuple consisting of the `(program as rulenode, program cost)`
"""
function generic_run(iterator::VannilaIterator; start_program::Union{Nothing,AbstractRuleNode}=nothing, stop_channel::Union{Nothing,Channel{Bool}}=nothing, max_running_time=0)
    print("typeof problem", typeof(iterator))
    rulenode, cost = HerbSearch.supervised_search(
        iterator,
        start_program=start_program,
        stop_channel=stop_channel,
        max_running_time=max_running_time
    )
    return rulenode, cost
end


# #TODO : Add generic run with ifs
# #TODO: Update the documentation
# function generic_run(combinator_iterator::CombinatorIterator, start_program::Union{Nothing,RuleNode}=nothing, stop_channel::Union{Nothing,Channel{Bool}}=nothing, max_running_time=0)
#     if combinator_iterator.combinator_type == SequenceCombinator
#         max_running_time = max_running_time == 0 ? MAX_SEQUENCE_RUNNING_TIME : max_running_time
#         return generic_run_sequence(combinator_iterator, start_program = start_program, stop_channel = stop_channel, max_running_time = max_running_time)
#     elseif combinator_iterator.combinator_type == ParallelThreads
#         return generic_run_parallel_threads(combinator_iterator, start_program = start_program, stop_channel = stop_channel, max_running_time = max_running_time)
#     end
#     error("Combinator type of $(combinator_iterator.combinator_type) not supported")
# end

"""
    generic_run(::Type{Sequence}, meta_search_list::Vector, max_depth::Int, grammar::ContextSensitiveGrammar; start_program::Union{Nothing,RuleNode} = nothing)

Runs an sequence of combinators represented by `meta_search_list`. 
Sequence(A,B,C) means that:
1. A is ran first and the outcome program of A is given to B.
2. B is ran second and the outcome program of B is given to C
3. C is ran third and the outcome program of C is the end outcome of the sequence step.
Note that `A`,`B`,`C` can be vanila algorithms or other combinators (sequence or parallel) 

## Notes
If the `start_program` of `A` is not given (e.g `nothing`) a random program is sampled from the grammar with the given `max_depth`.
The sequence step is stopped once an algorithm achieves cost `0`, meaning it satisfies all input/output examples.

Returns a tuple consisting of the `(program as rulenode, program cost)` coresponding to the best program found (lowest cost).
"""
function generic_run(
    combinator::SequenceCombinatorIterator;
    start_program::Union{Nothing,AbstractRuleNode}=nothing,
    stop_channel::Union{Nothing,Channel{Bool}}=nothing,
    max_running_time=MAX_SEQUENCE_RUNNING_TIME
 )
    start_time = time()

    best_program, program_cost = start_program, Inf64
    for meta_iterator ∈ combinator.iterators
        @warn "Starting new seq iteration!"
        if !isnothing(stop_channel) && !isempty(stop_channel)
            return best_program, program_cost
        end

        current_time = time() - start_time
        if current_time > max_running_time
            return best_program, program_cost
        end
        time_left = max_running_time - current_time
        start_program, cost = generic_run(meta_iterator, start_program=start_program, stop_channel=stop_channel, max_running_time=time_left)
        println("Starting with $start_program")
        if cost < program_cost
            best_program, program_cost = start_program, cost
        end
        # if we reached cost 0 then we have a working program, there is no point in continuing the sequence
        if cost == 0
            if !isnothing(stop_channel)
                HerbSearch.safe_put!(stop_channel, true)
                close(stop_channel)
            end
            break
        end
    end
    return best_program, program_cost
end


"""
    generic_run(::Type{Parallel}, meta_search_list::Vector, max_depth::Int, grammar::ContextSensitiveGrammar; start_program::Union{Nothing,RuleNode} = nothing)

Runs combinators in parallel from the `meta_search_list`. 
Parallel(A,B,C) means that A,B,C are ran in parallel on different threads.

## Notes
If the `start_program` of `A` is not given (e.g `nothing`) a random program is sampled from the grammar with the given `max_depth`.
The sequence step is stopped once an algorithm achieves cost `0`, meaning it satisfies all input/output examples.

Returns a tuple consisting of the `(program as rulenode, program cost)` coresponding to the best program found (lowest cost).
"""
function generic_run(
    combinator::ParallelCombinatorIterator;
    start_program::Union{Nothing,AbstractRuleNode}=nothing,
    stop_channel::Union{Nothing,Channel{Bool}}=nothing,
    max_running_time=MAX_SEQUENCE_RUNNING_TIME
)
    
    if isnothing(stop_channel)
        stop_channel = Channel{Bool}(1)
    end

    # use threads
    thread_list = [Threads.@spawn generic_run(meta_iterator, start_program=start_program, stop_channel=stop_channel, max_running_time=max_running_time) for meta_iterator ∈ combinator.iterators]

    # wait for all threads to finish
    best_program, program_cost = nothing, Inf64
    for (prog, cost) in fetch.(thread_list)
        # better cost
        if cost < program_cost
            best_program, program_cost = prog, cost
        end
    end
    if program_cost == 0
        HerbSearch.safe_put!(stop_channel, true)
        close(stop_channel)
    end

    return best_program, program_cost
end
