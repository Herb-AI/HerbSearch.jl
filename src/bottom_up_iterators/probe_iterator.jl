@programiterator mutable ProbeSynthesisIterator(
    spec::Vector{<:IOExample},
    max_bound::Int64,
    obs_equivalence::Bool = false
) <: BUBoundedIterator{RuleNode}

function bound_function(iter::ProbeSynthesisIterator, program::RuleNode)::Int64
    # Currently, the `log_probabilities` field is used to store the costs associated
    # with each rule.
    grammar = get_grammar(iter.solver)
    cost::Int64 = grammar.log_probabilities[program.ind]
    for child in program.children
        cost += bound_function(iter, child)
    end
    return cost
end

function combine_bound_function(
    iter::ProbeSynthesisIterator, 
    rule_idx::Int, 
    children_bounds::Vector{Int64}
)::Int64
    # Currently, the `log_probabilities` field is used to store the costs associated
    # with each rule.
    grammar = get_grammar(iter.solver)
    cost_root = grammar.log_probabilities[rule_idx]
    return cost_root + sum(children_bounds)
end

mutable struct WrappedProbeSynthesisIterator
    iter::ProbeSynthesisIterator
    iteration_result::Union{Tuple{RuleNode, BottomUpState{RuleNode}}, Nothing}

    # Used to recover the state when the iteration is continued by
    # increasing `max_bound`
    previous_state::Union{BottomUpState{RuleNode}, Nothing}
end

function WrappedProbeSynthesisIterator(
    iter::ProbeSynthesisIterator
)::WrappedProbeSynthesisIterator
    iteration_result = iterate(iter)
    return WrappedProbeSynthesisIterator(iter, iteration_result, nothing)
end

function Base.iterate(iter::WrappedProbeSynthesisIterator)::Union{RuleNode, Nothing}
    if isnothing(iter.iteration_result)
        return nothing
    end

    program, state = iter.iteration_result
    iter.previous_state = state
    iter.iteration_result = iterate(iter.iter, state)

    return program
end

Base.iterate(iter::WrappedProbeSynthesisIterator, _) = Base.iterate(iter)

function recover(iter::WrappedProbeSynthesisIterator)::Nothing
    iter.iteration_result = iterate(iter.iter, iter.previous_state)
    return nothing
end

Base.@doc """
    @programiterator ProbeIterator(
        spec::Union{Vector{<:IOExample}, Nothing} = nothing,
        obs_equivalence::Bool = false
    ) <: ProgramIterator
"""

@programiterator ProbeIterator(
    spec::Vector{<:IOExample},
    obs_equivalence::Bool = false
) <: ProgramIterator

struct ProbeFit
    current_fit::Vector{Float64} # Stores the `fit` metric for each rule for the current synthesis phase.
    new_fit::Dict{Int32, Float64} # Stores the updates to the `fit` metric that will be made prior to the next synthesis phase.
end

struct ProbeState
    synthesis_iter::WrappedProbeSynthesisIterator
    probe_fit::ProbeFit
    found_example_subsets::Set{Set{Int32}}
    uniform_cost::Int64
end

function Base.iterate(
    iter::ProbeIterator
)::Union{Tuple{RuleNode, ProbeState}, Nothing}
    grammar = get_grammar(iter.solver)
    uniform_cost = _probability2cost(1.0 / length(grammar.rules))
    probe_fit = ProbeFit([0 for _ in 1:length(grammar.rules)], Dict{Int32, Float64}())
    wrapped_synthesis_iter = _create_synthesis_iterator!(iter, probe_fit.current_fit, uniform_cost)
    found_example_subsets = Set{Set{Int32}}()

    probe_state = ProbeState(wrapped_synthesis_iter, probe_fit, found_example_subsets, uniform_cost)
    return _get_next_program(iter, probe_state)
end

function Base.iterate(
    iter::ProbeIterator,
    probe_state::ProbeState
)::Union{Tuple{RuleNode, ProbeState}, Nothing}
    return _get_next_program(iter, probe_state)
end

_probability2cost(p::Float64) = Int64(floor(-log2(p)))

_fit2probability(fit::Float64, uniform::Float64) = uniform ^ (1 - fit)

function _create_synthesis_iterator!(
    iter::ProbeIterator,
    fit::Vector{Float64},
    uniform_cost::Int64
)::WrappedProbeSynthesisIterator
    # Update rule costs
    grammar = get_grammar(iter.solver)
    uniform::Float64 = 1.0 / length(grammar.rules)
    z = sum([_fit2probability(f, uniform) for f in fit])
    rule_probabilities = [_fit2probability(f, uniform) / z for f in fit]
    grammar.log_probabilities = [_probability2cost(p) for p in rule_probabilities]

    max_bound_increase = 6 * uniform_cost # Heuristic chosen in the original Probe paper
    synthesis_iter = ProbeSynthesisIterator(
        grammar,
        :Number, # TODO: change this
        iter.spec,
        max_bound_increase,
        obs_equivalence = iter.obs_equivalence
    )
    return WrappedProbeSynthesisIterator(synthesis_iter)
end

function _get_next_program(
    iter::ProbeIterator,
    probe_state::ProbeState
)::Union{Tuple{RuleNode, ProbeState}, Nothing}
    while true
        program::Union{Nothing, RuleNode} = iterate(probe_state.synthesis_iter)

        if isnothing(program)
            # We finished the current synthesis cycle
            if isempty(probe_state.probe_fit.new_fit)
                # Didn't learn anything, so we continue the current synthesis phase.
                probe_state.synthesis_iter.iter.max_bound += 6 * probe_state.uniform_cost
                recover(probe_state.synthesis_iter)
            else
                println("TODO: see what happens when we are here")
                # Update the probabilities and setup the next synthesis phase.
                for (rule, fit) in probe_state.probe_fit.new_fit
                    probe_state.probe_fit.current_fit[rule] = fit
                end
                probe_state.probe_fit.new_fit = Dict{Int32, Float64}()
                probe_state.synthesis_iter = _create_synthesis_iterator(iter, probe_state.probe_fit.current_fit, probe_state.uniform_cost)
            end
        else
            satisfied_examples = _get_satisfied_example_subset(iter, program)
            satisfied_examples_count = length(satisfied_examples)
            
            if satisfied_examples_count == length(iter.spec)
                # The caller should realize this program satisfies all examples
                return program, probe_state
            
            elseif !(satisfied_examples in probe_state.found_example_subsets)
                push!(probe_state.found_example_subsets, satisfied_examples)
                extracted_rules = Set{Int32}()
                _extract_rules(program, extracted_rules)
                for rule in extracted_rules
                    fit = satisfied_examples_count / length(iter.spec)
                    if probe_state.probe_fit.current_fit[rule] >= fit
                        continue
                    end

                    if !haskey(probe_state.probe_fit.new_fit, rule) || probe_state.probe_fit[rule] >= fit
                        probe_state.probe_fit.new_fit[rule] = fit
                    end
                end
            end

            return program, probe_state
        end
    end
end

function _get_satisfied_example_subset(
    iter::ProbeIterator,
    program::RuleNode
)::Set{Int64}
    try
        observed_outputs = [execute_on_input(grammar, program, example.in) for example in spec]
        true_outputs = [example.out for example in spec]

        return Set(i for (i, (o1, o2)) in enumerate(zip(observed_outputs, true_outputs)) if o1 == o2)
    catch _
        return Set{Int64}()
    end
end

function _extract_rules(
    program::RuleNode,
    extracted_rules::Set{Int32}
)::Nothing
    push!(extracted_rules, program.ind)
    for child in program.children
        _extract_rules(child, extracted_rules)
    end
    return nothing
end