Base.@doc """
    @programiterator BUUniformIterator(problem::Problem{Vector{IOExample}}) <: BottomUpIterator

TODO
""" BUUniformIterator
@programiterator BUUniformIterator(
    spec::Union{Vector{<:IOExample}, Nothing} = nothing,
    obs_equivalence::Bool = false
) <: BottomUpIterator{UniformHole}

const Depth = UInt32

"""
    struct BUUniformBank <: BottomUpBank
"""
struct BUUniformBank <: BottomUpBank{UniformHole}
    depth_symbol_program_map::Dict{Depth, Dict{Symbol, Vector{UniformHole}}}
end

BottomUpBank{UniformHole}(iter::BUUniformIterator) = BUUniformBank(iter)

"""
	BUUniformBank(iter::BUDepthIterator)::BUDepthBank
"""
function BUUniformBank(
    iter::BUUniformIterator
)::BUUniformBank
    depth_symbol_program_map = Dict{Depth, Dict{Symbol, Vector{UniformHole}}}()
    bank = BUUniformBank(depth_symbol_program_map)

    _increase_bound!(iter, bank, UInt32(1))

    return bank
end

"""
    struct BUUniformData <: BottomUpData
"""
mutable struct BUUniformData <: BottomUpData{UniformHole}
    current_depth::Depth
    unused_rules::Queue{UniformHole}
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker}
end

BottomUpData{UniformHole}(iter::BUUniformIterator) = BUUniformData(iter)

"""
    BUUniformData(iter::BUDepthIterator)::BUDepthData
"""
function BUUniformData(
    iter::BUUniformIterator
)::BUUniformData
    unused_rules = _create_unused_rules(iter, true)
    current_depth = 1
    
    # TODO: Try to do observational equivalence on UniformTrees.
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker} = nothing

    return BUUniformData(current_depth, unused_rules, obs_checker)
end

function combine!(
    iter::BUUniformIterator,
    bank::BUUniformBank,
    data::BUUniformData
)::Union{RuleNodeCombinations, Nothing}
    grammar = get_grammar(iter.solver)
    max_depth = get_max_depth(iter.solver)

    while true
        # Check if we enumerated all programs for the current depth.
        if isempty(data.unused_rules)
            data.current_depth += 1
            _increase_bound!(iter, bank, data.current_depth)
 
            # Check if we reached the depth limit.
            if data.current_depth > max_depth
                return nothing
            end

            # Add all nonterminals to the `unused_rules` queue.
            data.unused_rules = _create_unused_rules(iter, false)
            continue
        end

        rule = dequeue!(data.unused_rules)
        childtypes = grammar.childtypes[findfirst(rule.domain)]
        children_lists = map(symbol -> bank.depth_symbol_program_map[data.current_depth][symbol], childtypes)
        return RuleNodeCombinations(rule, children_lists)
    end
end

function is_valid(
    iter::BUUniformIterator,
    program::UniformHole,
    data::BUUniformData
)::Bool
    if depth(program) ≠ data.current_depth
        return false
    end

    # Observational equivalence is not yet handled on UniformTrees.
    return true
end

function add_to_bank!(
    iter::BUUniformIterator,
    bank::BUUniformBank,
    program::UniformHole
)::Nothing
    grammar = get_grammar(iter.solver)
    program_depth = depth(program) # TODO: this might be slow.
    symbol = grammar.types[findfirst(program.domain)]
    push!(bank.depth_symbol_program_map[program_depth][symbol], program)
    return nothing
end

function _increase_bound!(
    iter::BUUniformIterator,
    bank::BUUniformBank,
    new_depth::Depth
)
    dict = bank.depth_symbol_program_map
    dict[new_depth] = Dict{Symbol, Vector{UniformHole}}()

    grammar = get_grammar(iter.solver)
    for type ∈ grammar.types
        dict[new_depth][type] = Vector{UniformHole}()
        for depth in 1:(new_depth-1)
            append!(dict[new_depth][type], dict[depth][type])
        end
    end
end

function _create_unused_rules(
    iter::BUUniformIterator,
    terminals::Bool
)::Queue{UniformHole}
    grammar = get_grammar(iter.solver)

    # Store the rules we need to partition into UniformHoles.
    rules::BitVector = grammar.isterminal
    if !terminals
        rules = rules .⊻ BitVector(fill(true, length(rules)))
    end

    symbol_to_rules::Dict{Symbol, BitVector} = grammar.domains
    hole_domains = Vector{BitVector}()
    for (_, rules_for_symbol) ∈ symbol_to_rules
        # Only partition terminal/non-terminal rules (based on `terminals`).
        domain = rules_for_symbol .&& rules
        append!(hole_domains, partition(Hole(domain), grammar))
    end

    uniform_roots = Queue{UniformHole}()
    for domain ∈ hole_domains
        enqueue!(uniform_roots, UniformHole(domain, Vector{UniformHole}()))
    end

    return uniform_roots
end