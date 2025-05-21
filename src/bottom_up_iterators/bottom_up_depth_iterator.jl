Base.@doc """
    @programiterator BUDepthIterator{T}(spec::Union{Nothing, Problem{Vector{IOExample}}}=nothing, obs_equivalence::Bool=false) <: BottomUpIterator{T})

TODO
""" BUDepthIterator
@programiterator BUDepthIterator{T}(
    spec::Union{Vector{<:IOExample}, Nothing} = nothing,
    obs_equivalence::Bool = false
) <: BottomUpIterator{T}

const Depth = UInt32

struct BUDepthBank{T} <: BottomUpBank{T}
    depth_symbol_program_map::Dict{Depth, Dict{Symbol, Vector{T}}}
end

BottomUpBank{T}(iter::BUDepthIterator{T}) where T = BUDepthBank{T}(iter)

function BUDepthBank{T}(
    iter::BUDepthIterator{T}
)::BUDepthBank{T} where T
    depth_symbol_program_map = Dict{Depth, Dict{Symbol, Vector{T}}}()
    bank = BUDepthBank{T}(depth_symbol_program_map)

    _increase_bound!(iter, bank, UInt32(1))

    return bank
end

mutable struct BUDepthData{T} <: BottomUpData{T}
    current_depth::Depth
    unused_rules::Queue{T}
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker{T}}
end

BottomUpData{T}(iter::BUDepthIterator{T}) where T = BUDepthData{T}(iter)

function BUDepthData{T}(
    iter::BUDepthIterator{T}
)::BUDepthData{T} where T
    unused_rules = _create_unused_rules(iter, true)
    current_depth = 1

    obs_checker::Union{Nothing, ObservationalEquivalenceChecker{T}} = nothing
    if iter.obs_equivalence
        @assert !isnothing(iter.spec) "If `iter.obs_equivalence` is set to `true`, `spec` must not be `nothing`."
        obs_checker = ObservationalEquivalenceChecker{T}()
    end
 
    return BUDepthData{T}(current_depth, unused_rules, obs_checker)
end

function combine!(
    iter::BUDepthIterator{T},
    bank::BUDepthBank{T},
    data::BUDepthData{T}
)::Union{RuleNodeCombinations{T}, Nothing} where T
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
        childtypes = grammar.childtypes[_get_first_rule_index(rule)]
        children_lists = map(symbol -> bank.depth_symbol_program_map[data.current_depth][symbol], childtypes)
        return RuleNodeCombinations(rule, children_lists)
    end
end


function is_valid(
    iter::BUDepthIterator{T},
    program::T,
    data::BUDepthData{T}
)::Bool where T
    if depth(program) ≠ data.current_depth # TODO: `depth` call is slow.
        return false
    end

    if isnothing(data.obs_checker) 
        return true
    end

    return is_new_program!(data.obs_checker, program, get_grammar(iter.solver), iter.spec)
end

function add_to_bank!(
    iter::BUDepthIterator{T},
    bank::BUDepthBank{T},
    program::T
)::Nothing where T
    grammar = get_grammar(iter.solver)
    program_depth = depth(program) # TODO: `depth` call is slow.

    # Add the program to the appropriate collection
    symbol = grammar.types[_get_first_rule_index(program)]
    push!(bank.depth_symbol_program_map[program_depth][symbol], program)
    return nothing
end

function _increase_bound!(
    iter::BUDepthIterator{T},
    bank::BUDepthBank{T},
    new_depth::Depth
)::Nothing where T
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

function _get_first_rule_index(
    node::RuleNode
)::Int64
    return node.ind
end

function _get_first_rule_index(
    node::UniformHole
)::Int64
    return findfirst(node.domain)
end

function _create_unused_rules(
    iter::BUDepthIterator{RuleNode},
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

function _create_unused_rules(
    iter::BUDepthIterator{UniformHole},
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