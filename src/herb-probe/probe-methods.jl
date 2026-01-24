
using DocStringExtensions
using HerbCore
using HerbGrammar
using HerbSpecification
using HerbInterpret
using HerbConstraints

# iterator::ProgramIterator

# synth_fn::Function

# stop_checker::Function = (timed_solution) -> Bool

# selector::Function = results -> results
# updater::Function = (selected, iter) -> iter
    # Pkg.develop(path="C:/Users/chris/.julia/dev/HerbSearch")


"""
    $(TYPEDSIGNATURES)

Iterates over the solutions to find partial or full solutions.
Takes an iterator to enumerate programs. Quits when `max_time` or `max_enumerations` is reached.
If the program solves the problem, it is returned with the `optimal_program` flag.
If a program solves some of the problem (e.g. some but not all examples) it is added to the list of `promising_programs`.
The set of promising programs is returned eventually.
"""
function get_promising_programs_with_fitness(
        iterator::ProgramIterator,
        problem::Problem;
        max_time = typemax(Int),
        max_enumerations = typemax(Int),
        interpreter::Function,
        tags
# )::Tuple{Set{Tuple{AbstractRuleNode, Real}}, SynthResult}
)::Tuple{Set{Tuple{AbstractRuleNode, Real}}, SynthResult}
    start_time = time()
    grammar = HerbConstraints.get_grammar(iterator.solver)

    if isnothing(grammar.log_probabilities)
        init_probabilities!(grammar)
        normalize!(grammar)
    end

    promising_programs = Set{Tuple{AbstractRuleNode, Real}}()

    for (i, candidate_program) in enumerate(iterator)
        fitness = decide_probe(candidate_program, problem, grammar, interpreter, tags)

        if fitness == 1
            push!(promising_programs, (freeze_state(candidate_program), fitness))
            return (promising_programs, optimal_program)
        elseif fitness > 0
            push!(promising_programs, (freeze_state(candidate_program), fitness))
        end

        # Check stopping criteria
        if i > max_enumerations || time() - start_time > max_time
            break
        end
    end

    return (promising_programs, suboptimal_program)
end

"""
    $(TYPEDSIGNATURES)

# Decide whether to keep a program, or discard it, based on the specification. 
# Returns the portion of solved examples.
# """
function decide_probe(program::AbstractRuleNode,
                    problem::Problem,
                    grammar::ContextSensitiveGrammar,
                    interpreter::Function,
                    tags)::Real
    # interpret program on each example, compute fraction correct
    correct = 0
    for ex in problem.spec
        out = try
            interpreter(program, tags, ex.in)
        catch
            return 0.0
        end
        correct += (out == ex.out)
        # println(out)
    end
    # println("expr = ", rulenode2expr(program, grammar))
    # println("Cyclecomplete")
    # println(correct/length(problem.spec))
    return correct / length(problem.spec)
end


function create_probe_synth_fn(
        interpreter::Function,
        tags;
        maximum_time = typemax(Int),
        maximum_enumerations = typemax(Int))
    return (problem::Problem, iterator::ProgramIterator) -> begin
        get_promising_programs_with_fitness(
            iterator, problem;
            max_time = maximum_time,
            max_enumerations = maximum_enumerations,
            interpreter = interpreter,
            tags = tags
        )
    end
end

function probe_selector(variable) 
    return variable[1]
end

function probe_stop_checker(variable)
    return variable.value[2] == optimal_program
end

"""
    $(TYPEDSIGNATURES)

Modify the grammar based on the programs kept during the `decide` step.
Takes a set of programs and their fitnesses, which describe how useful the respective program is.
Updates a rules probability based on the highest program fitness the rule occurred in. 
The update function is taken from the Probe paper. Instead of introducing a normalization value, we just call `normalize!` instead.
"""
function modify_grammar_probe!(
        saved_program_fitness::Set{Tuple{<:AbstractRuleNode, Real}},
        grammar::AbstractGrammar
)::AbstractGrammar 
    # orig_probs = exp.(grammar.log_probabilities)
    # println(length(orig_probs))
    # borig = copy(orig_probs)



    # println("new cycle")
    # before = copy(grammar.log_probabilities)
    # # println(before)
    # # println(length(before))

    
    # for i in 1:length(grammar.log_probabilities)
    #     max_fitness = 0

    #     # Find maximum fitness for programs with that rule among saved programs
    #     for (program, fitness) in saved_program_fitness
    #         if !isempty(rulesoftype(program, Set(i))) && fitness > max_fitness
    #             max_fitness = fitness                
    #         end
    #     end

    #     # Update the probability according to Probe's formula
    #     prob = log_probability(grammar, i)
    #     orig_probs[i] = log(exp(prob)^(1-max_fitness))

    # end
    # aorig = copy(orig_probs)
    # println(any(borig .!= aorig))
    # grammar.log_probabilities .= orig_probs

    # # Normalize probabilities after the update
    # normalize!(grammar)

    # # after = copy(grammar.log_probabilities)
    # # println(length(after))

    # # println(after)

    # println(any(before .!= grammar.log_probabilities))

    # return grammar

    logps = copy(grammar.log_probabilities)
    # logps2 = copy(grammar.log_probabilities)

    # println(grammar.log_probabilities)


for i in eachindex(logps)
    max_fitness = 0.0
    for (program, fitness) in saved_program_fitness
        if fitness > max_fitness && !isempty(rulesoftype(program, Set(i)))
            max_fitness = float(fitness)
        end
    end

    # your formula simplifies to:
    # log(exp(logp)^(1-max_fitness)) == (1-max_fitness) * logp
    logps[i] = (1 - max_fitness) * logps[i]
end

grammar.log_probabilities .= logps
normalize!(grammar)

# println(grammar.log_probabilities)
# println(any(logps2 .!= grammar.log_probabilities))



return grammar

end

function create_probe_updater(iterator_ctor, starting_sym::Symbol; kwargs...)
    return (promising, old_iter::ProgramIterator) -> begin
        g = HerbConstraints.get_grammar(old_iter.solver)
        modify_grammar_probe!(promising, g)
        return iterator_ctor(g, starting_sym; kwargs...)
    end
end

