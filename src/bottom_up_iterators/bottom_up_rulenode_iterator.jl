Base.@doc """
    @programiterator BURulenodeIterator(spec::Union{Nothing, Problem{Vector{IOExample}}}=nothing, obs_equivalence::Bool=false) <: BottomUpIterator

Implementation of the `BottomUpIterator`. Iterates through complete programs in increasing order of their depth.
""" BURulenodeIterator
@programiterator BURulenodeIterator(
    spec::Union{Vector{<:IOExample}, Nothing} = nothing,
    obs_equivalence::Bool = false
) <: BottomUpIterator{RuleNode}

const Depth = UInt32

"""
    struct BURulenodeBank <: BottomUpBank
"""
struct BURulenodeBank <: BottomUpBank{RuleNode}
    depth_symbol_program_map::Dict{Depth, Dict{Symbol, Vector{RuleNode}}}
end

BottomUpBank{RuleNode}(iter::BURulenodeIterator) = BURulenodeBank(iter)

"""
	BURulenodeBank(iter::BURulenodeIterator)::BUDepthBank
"""
function BURulenodeBank(
    iter::BURulenodeIterator
)::BURulenodeBank
    depth_symbol_program_map = Dict{Depth, Dict{Symbol, Vector{RuleNode}}}()
    bank = BURulenodeBank(depth_symbol_program_map)

    _increase_bound!(iter, bank, UInt32(1))

    return bank
end

"""
    struct BURulenodeData <: BottomUpData

TODO: Explain each field of this class.
"""
mutable struct BURulenodeData <: BottomUpData{RuleNode}
    current_depth::Depth
    unused_rules::Queue{RuleNode}
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker}
end

BottomUpData{RuleNode}(iter::BURulenodeIterator) = BURulenodeData(iter)

"""
    BURulenodeData(iter::BURulenodeIterator)::BUDepthData
"""
function BURulenodeData(
    iter::BURulenodeIterator
)::BURulenodeData
    unused_rules = _create_unused_rules(iter, true)
    current_depth = 1

    obs_checker::Union{Nothing, ObservationalEquivalenceChecker} = nothing
    if iter.obs_equivalence
        @assert !isnothing(iter.spec) "If `iter.obs_equivalence` is set to `true`, `spec` must not be `nothing`."
        obs_checker = ObservationalEquivalenceChecker()
    end
 
    return BURulenodeData(current_depth, unused_rules, obs_checker)
end

function combine!(
    iter::BURulenodeIterator,
    bank::BURulenodeBank,
    data::BURulenodeData
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
        childtypes = grammar.childtypes[rule.ind]
        children_lists = map(symbol -> bank.depth_symbol_program_map[data.current_depth][symbol], childtypes)
        return RuleNodeCombinations(rule, children_lists)
    end
end

function is_valid(
    iter::BURulenodeIterator,
    program::RuleNode,
    data::BURulenodeData
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
    iter::BURulenodeIterator,
    bank::BURulenodeBank,
    program::RuleNode
)::Nothing
    grammar = get_grammar(iter.solver)
    program_depth = depth(program) # TODO: this might be slow.
    symbol = grammar.types[program.ind]
    push!(bank.depth_symbol_program_map[program_depth][symbol], program)
    return nothing
end

function _increase_bound!(
    iter::BURulenodeIterator,
    bank::BURulenodeBank,
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
    iter::BURulenodeIterator,
    terminals::Bool
)::Queue{RuleNode}
    grammar = get_grammar(iter.solver)
    unused_rules = Queue{RuleNode}()

    for (rule, is_terminal) in enumerate(grammar.isterminal)
        if is_terminal == terminals
            enqueue!(unused_rules, RuleNode(rule))
        end
    end
    return unused_rules
end