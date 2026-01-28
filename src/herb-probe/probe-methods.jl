
using DocStringExtensions
using HerbCore
using HerbGrammar
using HerbSpecification
using HerbInterpret
using HerbConstraints

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

Decide whether to keep a program, or discard it, based on the specification. 
 Returns the portion of solved examples.
 """
function decide_probe(program::AbstractRuleNode,
                    problem::Problem,
                    grammar::ContextSensitiveGrammar,
                    interpreter::Function,
                    tags)::Real
    # interpret program on each example, compute fraction correct
    correct = 0
    for ex in problem.spec
        out = try
            Base.invokelatest(interpreter, program, tags, ex.in)
        catch
            return 0.0
        end
        correct += (out == ex.out)
    end
    return correct / length(problem.spec)
end

"""

    $(TYPEDSIGNATURES)


Construct a synthesis function compatible with the shared `BudgetedSearchController`.

The returned function has signature `(problem::Problem, iterator::ProgramIterator) -> (promising, status)` and
runs `get_promising_programs_with_fitness` using the provided `interpreter` and `tags`.

A closure suitable to be passed as `synth_fn` to the controller.
"""
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

"""

    $(TYPEDSIGNATURES)

Selector policy that keeps *all* promising programs produced by the synth function.

This expects `variable` to be the value returned by `synth_fn`, i.e. a tuple
`(promising_set, status)` where `promising_set` is a set of `(program, fitness)` pairs.
"""
function probe_selector_all(variable) 
    return variable[1]
end

"""

    $(TYPEDSIGNATURES)
    
Selector policy that keeps only the promising program with the higest fitness produced by the synth function.

This expects `variable` to be the value returned by `synth_fn`, i.e. a tuple
`(promising_set, status)` where `promising_set` is a set of `(program, fitness)` pairs.
"""
function probe_selector_best(variable)
    promising = variable[1]
    isempty(promising) && return Set{Tuple{AbstractRuleNode, Real}}()

    best = reduce((a,b) -> (a[2] >= b[2] ? a : b), promising)

    out = Set{Tuple{AbstractRuleNode, Real}}()
    push!(out, (best[1], best[2]))
    return out
end

"""

    $(TYPEDSIGNATURES)
    
Selector policy that keeps all promising programs produced by the synth function that have a fitness > 0.2.

This expects `variable` to be the value returned by `synth_fn`, i.e. a tuple
`(promising_set, status)` where `promising_set` is a set of `(program, fitness)` pairs.
"""
function probe_selector_non_trivial(variable)
    promising = variable[1]
    
    return filter(p -> p[2] > 0.2, promising)
end


"""
    $(TYPEDSIGNATURES)

This is designed to be used with `@timed synth_fn(...)` output passed by the controller
(i.e., a `Timed` object-like value), and checks:

- Stop if the synth result status indicates an optimal program was found, or
- Stop if no promising programs were found.

Concretely, it expects:
- `variable.value[1]` is the set of promising programs
- `variable.value[2]` is a `SynthResult` (e.g., `optimal_program`, `suboptimal_program`)
"""
function probe_stop_checker(variable)
    return variable.value[2] == optimal_program || isempty(variable.value[1])
end

"""
    $(TYPEDSIGNATURES)

Modify the grammar based on the programs kept during the `decide` step.
Uses the probabilities of the current grammar to do so in an *iterative* fashion.
Takes a set of programs and their fitnesses, which describe how useful the respective program is.
Updates a rules probability based on the highest program fitness the rule occurred in. 
The update function is taken from the Probe paper. Instead of introducing a normalization value, we just call `normalize!` instead.
"""
function modify_grammar_probe_iterative!(
        saved_program_fitness::Set{Tuple{<:AbstractRuleNode, Real}},
        grammar::AbstractGrammar
)::AbstractGrammar 
    logps = copy(grammar.log_probabilities)

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

    return grammar

end

"""
    $(TYPEDSIGNATURES)

Modify the grammar based on the programs kept during the `decide` step.
Uses the a fresh uniform distribution of probabilities do so in the *original* implementation.
Takes a set of programs and their fitnesses, which describe how useful the respective program is.
Updates a rules probability based on the highest program fitness the rule occurred in. 
The update function is taken from the Probe paper. Instead of introducing a normalization value, we just call `normalize!` instead.
"""
function modify_grammar_probe_original!(
        saved_program_fitness::Set{Tuple{<:AbstractRuleNode, Real}},
        grammar::AbstractGrammar
)::AbstractGrammar 
    logps = copy(grammar.log_probabilities)

    for i in eachindex(logps)
        max_fitness = 0.0
        for (program, fitness) in saved_program_fitness
            if fitness > max_fitness && !isempty(rulesoftype(program, Set(i)))
                max_fitness = float(fitness)
            end
        end

        # your formula simplifies to:
        # log(exp(logp)^(1-max_fitness)) == (1-max_fitness) * logp
        logps[i] = (1 - max_fitness) * -log(length(logps))
    end

    grammar.log_probabilities .= logps
    normalize!(grammar)

    return grammar

end

"""
    $(TYPEDSIGNATURES)

Modify the grammar based on the programs kept during the `decide` step.
Uses the a fresh grammar of probabilities do so in but one that is *normalized*.
Takes a set of programs and their fitnesses, which describe how useful the respective program is.
Updates a rules probability based on the highest program fitness the rule occurred in. 
The update function is taken from the Probe paper. Instead of introducing a normalization value, we just call `normalize!` instead.
"""
function modify_grammar_probe_hybrid!(
        saved_program_fitness::Set{Tuple{<:AbstractRuleNode, Real}},
        grammar::AbstractGrammar
)::AbstractGrammar 
    gcopy = deepcopy(grammar)
    normalize!(gcopy)

    logps = copy(gcopy.log_probabilities)

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

    return grammar

end

"""
Create an updater closure implementing the *iterative* Probe-style grammar update.

The returned updater has signature `(promising, old_iter::ProgramIterator) -> ProgramIterator`:
1. Extracts the grammar from `old_iter`,
2. Updates it in-place using `modify_grammar_probe_iterative!`,
3. Constructs a fresh iterator via `iterator_ctor(updated_grammar, starting_sym; kwargs...)`.

# Arguments
- `iterator_ctor`: A constructor that builds a new `ProgramIterator` from a grammar and start symbol.
- `starting_sym`: Grammar start symbol for enumeration.
- `kwargs...`: Passed through to `iterator_ctor`.
"""
function create_probe_updater_iterative(iterator_ctor, starting_sym::Symbol; kwargs...)
    return (promising, old_iter::ProgramIterator) -> begin
        g = HerbConstraints.get_grammar(old_iter.solver)
        modify_grammar_probe_iterative!(promising, g)
        return iterator_ctor(g, starting_sym; kwargs...)
    end
end

"""
Create an updater closure implementing the *original/reset-like* Probe grammar update.

The returned updater has signature `(promising, old_iter::ProgramIterator) -> ProgramIterator`:
1. Extracts the grammar from `old_iter`,
2. Updates it in-place using `modify_grammar_probe_original!`,
3. Constructs a fresh iterator via `iterator_ctor(updated_grammar, starting_sym; kwargs...)`.

# Arguments
- `iterator_ctor`: A constructor that builds a new `ProgramIterator` from a grammar and start symbol.
- `starting_sym`: Grammar start symbol for enumeration.
- `kwargs...`: Passed through to `iterator_ctor`.
"""
function create_probe_updater_original(iterator_ctor, starting_sym::Symbol; kwargs...)
    return (promising, old_iter::ProgramIterator) -> begin
        g = HerbConstraints.get_grammar(old_iter.solver)
        modify_grammar_probe_original!(promising, g)
        return iterator_ctor(g, starting_sym; kwargs...)
    end
end

"""
Create an updater closure implementing the *hybrid* Probe grammar update.

Unlike the iterative/original variants that update the grammar extracted from the iterator,
the hybrid updater:
1. Starts from a deep copy of the provided `og_grammar` each cycle,
2. Applies `modify_grammar_probe_hybrid!` using the selected promising programs,
3. Constructs a new iterator from this updated copy.

This can reduce “drift” or lock-in effects by re-centering updates around an original grammar.

# Arguments
- `iterator_ctor`: A constructor that builds a new `ProgramIterator` from a grammar and start symbol.
- `starting_sym`: Grammar start symbol for enumeration.
- `og_grammar`: Reference grammar used as the baseline each cycle (copied before updating).
- `kwargs...`: Passed through to `iterator_ctor`.
"""
function create_probe_updater_hybrid(iterator_ctor, starting_sym::Symbol, og_grammar::AbstractGrammar; kwargs...)
    return (promising, old_iter::ProgramIterator) -> begin
        g = deepcopy(og_grammar)
        modify_grammar_probe_hybrid!(promising, g)
        return iterator_ctor(g, starting_sym; kwargs...)
    end
end

