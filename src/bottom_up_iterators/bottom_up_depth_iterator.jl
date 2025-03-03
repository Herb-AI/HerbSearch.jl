Base.@doc """
    @programiterator BUDepthIterator(problem::Union{Nothing, Problem{Vector{IOExample}}}=nothing, obs_equivalence::Bool=false) <: BottomUpIterator

Implementation of the `BottomUpIterator`. Iterates through complete programs in increasing order of their depth.
""" BUDepthIterator
@programiterator BUDepthIterator(
    spec::Union{Vector{<:IOExample}, Nothing} = nothing,
    obs_equivalence::Bool = false
) <: BottomUpIterator

const Depth = UInt32

"""
    struct BUDepthBank <: BottomUpBank
"""
struct BUDepthBank <: BottomUpBank
    depth_symbol_program_map::Dict{Depth, Dict{Symbol, Vector{RuleNode}}}
end

BottomUpBank(iter::BUDepthIterator) = BUDepthBank(iter)

"""
	BUDepthBank(iter::BUDepthIterator)::BUDepthBank
"""
function BUDepthBank(
    iter::BUDepthIterator
)::BUDepthBank
    depth_symbol_program_map = Dict{Depth, Dict{Symbol, Vector{RuleNode}}}()
    bank = BUDepthBank(depth_symbol_program_map)

    _increase_bound!(iter, bank, UInt32(1))

    return bank
end

"""
    struct BUDepthData <: BottomUpData

TODO: Explain each field of this class.
"""
mutable struct BUDepthData <: BottomUpData
    current_depth::Depth
    unused_rules::Queue{Int}
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker}
end

BottomUpData(iter::BUDepthIterator) = BUDepthData(iter)

"""
    BUDepthData(iter::BUDepthIterator)::BUDepthData
"""
function BUDepthData(
    iter::BUDepthIterator
)::BUDepthData
    unused_rules = _create_unused_rules(iter, true)
    current_depth = 1
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker} = nothing
    if iter.obs_equivalence
        obs_checker = ObservationalEquivalenceChecker()
    end
    return BUDepthData(current_depth, unused_rules, obs_checker)
end

function combine!(
    iter::BUDepthIterator,
    bank::BUDepthBank,
    data::BUDepthData
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
        children_lists = map(symbol -> bank.depth_symbol_program_map[data.current_depth][symbol], grammar.childtypes[rule])
        return RuleNodeCombinations(rule, children_lists)
    end
end

function is_valid(
    iter::BUDepthIterator,
    program::RuleNode,
    data::BUDepthData
)::Bool
    if depth(program) ≠ data.current_depth
        return false
    end

    if isnothing(data.obs_checker) 
        return true
    end

    return is_new_program!(data.obs_checker, program, get_grammar(iter.solver), iter.spec)
end

function add_to_bank!(
    iter::BUDepthIterator,
    bank::BUDepthBank,
    program::RuleNode
)::Nothing
    grammar = get_grammar(iter.solver)
    program_depth = depth(program) # TODO: this might be slow.
    symbol = grammar.types[program.ind]
    push!(bank.depth_symbol_program_map[program_depth][symbol], program)
    return nothing
end

function _increase_bound!(
    iter::BUDepthIterator,
    bank::BUDepthBank,
    new_depth::Depth
)
    dict = bank.depth_symbol_program_map
    dict[new_depth] = Dict{Symbol, Vector{RuleNode}}()

    grammar = get_grammar(iter.solver)
    for type ∈ grammar.types
        dict[new_depth][type] = Vector{RuleNode}()
        for depth in 1:(new_depth-1)
            append!(dict[new_depth][type], dict[depth][type])
        end
    end
end

function _create_unused_rules(
    iter::BUDepthIterator,
    terminals::Bool
)::Queue{Int}
    grammar = get_grammar(iter.solver)
    unused_rules = Queue{Int}()
    for (rule, is_terminal) in enumerate(grammar.isterminal)
        if is_terminal == terminals
            enqueue!(unused_rules, rule)
        end
    end
    return unused_rules
end