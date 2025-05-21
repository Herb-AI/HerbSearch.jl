"""
    abstract type BUBoundedIterator{T <: AbstractRuleNode} <: BottomUpIterator{T}

A generalized bottom-up iterator that enumerates programs based on a generic "bound" value
(which could be depth, size, or any other cost metric) represented as a Int64.

Concrete implementations must define:
- `bound_function(iter, program)::Int64`: Calculates the bound of an existing program
- `combine_bound_function(iter, rule_idx, children_bounds)::Int64`: Calculates bound for a new program
"""
abstract type BUBoundedIterator{T <: AbstractRuleNode} <: BottomUpIterator{T} end

function bound_function(iter::BUBoundedIterator{T}, program::T)::Int64 where T
    error("bound_function not implemented for $(typeof(iter))")
end

function combine_bound_function(
    iter::BUBoundedIterator{T}, 
    rule_idx::Int, 
    children_bounds::Vector{Int64}
)::Int64 where T
    error("combine_bound_function not implemented for $(typeof(iter))")
end

struct BUBoundedBank{T <: AbstractRuleNode} <: BottomUpBank{T}
    bound_symbol_program_map::Dict{Int64, Dict{Symbol, Vector{T}}}
end

BottomUpBank{T}(iter::BUBoundedIterator{T}) where T = BUBoundedBank{T}(iter)

function BUBoundedBank{T}(
    iter::BUBoundedIterator{T}
)::BUBoundedBank{T} where T <: AbstractRuleNode
    bound_symbol_program_map = Dict{Int64, Dict{Symbol, Vector{T}}}()
    bank = BUBoundedBank{T}(bound_symbol_program_map)
    
    initial_bound = 1
    _initialize_bound!(iter, bank, initial_bound)
    
    return bank
end

mutable struct BUBoundedData{T <: AbstractRuleNode} <: BottomUpData{T}
    current_bound::Int64
    unused_rules::Queue{T}
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker{T}}
end

BottomUpData{T}(iter::BUBoundedIterator{T}) where T = BUBoundedData{T}(iter)

function BUBoundedData{T}(
    iter::BUBoundedIterator{T}
)::BUBoundedData{T} where T
    initial_bound = 1
    @assert !hasfield(typeof(iter), :max_bound) || initial_bound <= iter.max_bound "The initial bound shouldn't be larger than the indicated max bound."

    unused_rules = _create_unused_rules(iter, true)  # Start with terminal rules
    
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker{T}} = nothing
    if hasfield(typeof(iter), :obs_equivalence) && iter.obs_equivalence
        @assert hasfield(typeof(iter), :spec) && !isnothing(iter.spec) "If `obs_equivalence` is true, `spec` must not be `nothing`."
        obs_checker = ObservationalEquivalenceChecker{T}()
    end
 
    return BUBoundedData{T}(initial_bound, unused_rules, obs_checker)
end

function combine!(
    iter::BUBoundedIterator{T},
    bank::BUBoundedBank{T},
    data::BUBoundedData{T}
)::Union{RuleNodeCombinations{T}, Nothing} where T
    grammar = get_grammar(iter.solver)
    max_depth = get_max_depth(iter.solver)
    
    while true
        # Check if we've exhausted all rules for the current bound
        if isempty(data.unused_rules)
            data.current_bound += 1
            _initialize_bound!(iter, bank, data.current_bound)
            
            if hasfield(typeof(iter), :max_bound) && data.current_bound > iter.max_bound
                return nothing
            end

            # Add all nonterminals to the `unused_rules` queue.
            data.unused_rules = _create_unused_rules(iter, false)
            continue
        end
 
        rule = dequeue!(data.unused_rules)
        rule_idx = _get_first_rule_index(rule)
        childtypes = grammar.childtypes[rule_idx]
        
        children_lists = Vector{Vector{T}}()
        
        for child_type ∈ childtypes
            child_programs = Vector{T}()
            
            for bound ∈ 1:data.current_bound
                # For now just collect all programs of smaller bounds
                # (a more efficient implementation would filter based on combine_bound_function)
                append!(child_programs, bank.bound_symbol_program_map[bound][child_type])
            end
 
            push!(children_lists, child_programs)
        end
        
        return RuleNodeCombinations{T}(rule, children_lists)
    end
end

function is_valid(
    iter::BUBoundedIterator{T},
    program::T,
    data::BUBoundedData{T}
)::Bool where T
    # Check if the program's bound matches the current bound we're exploring
    if bound_function(iter, program) ≠ data.current_bound # TODO: `bound_function` call is slow.
        return false
    end

    if isnothing(data.obs_checker) 
        return true
    end

    return is_new_program!(data.obs_checker, program, get_grammar(iter.solver), iter.spec)
end

function add_to_bank!(
    iter::BUBoundedIterator{T},
    bank::BUBoundedBank{T},
    program::T
)::Nothing where T
    grammar = get_grammar(iter.solver)
    program_bound = bound_function(iter, program) # TODO: `bound_function` call is slow.
    
    # Add the program to the appropriate collection
    symbol = grammar.types[_get_first_rule_index(program)]
    push!(bank.bound_symbol_program_map[program_bound][symbol], program)
    
    return nothing
end

function _initialize_bound!(
    iter::BUBoundedIterator{T},
    bank::BUBoundedBank{T},
    bound::Int64
)::Nothing where T
    bank.bound_symbol_program_map[bound] = Dict{Symbol, Vector{T}}()

    # Initialize program vectors for each symbol
    grammar = get_grammar(iter.solver)
    for type in grammar.types
        bank.bound_symbol_program_map[bound][type] = Vector{T}()
    end
    
    return nothing
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
    iter::BUBoundedIterator{RuleNode},
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
    iter::BUBoundedIterator{UniformHole},
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