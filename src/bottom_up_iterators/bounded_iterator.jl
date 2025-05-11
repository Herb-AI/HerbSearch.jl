"""
    abstract type Bounded_BU_Iterator{T <: AbstractRuleNode} <: BottomUpIterator{T}

A generalized bottom-up iterator that enumerates programs based on a generic "bound" value
(which could be depth, size, or any other cost metric) represented as a Float64.

Concrete implementations must define:
- `get_initial_bound(iter)::Float64`: Returns the smallest possible bound (e.g., for terminals)
- `bound_function(iter, program)::Float64`: Calculates the bound of an existing program
- `combine_bound_function(iter, rule_idx, children_bounds)::Float64`: Calculates bound for a new program
- `next_bound(iter, current_bound)::Float64`: Calculates the next bound to explore
"""
abstract type Bounded_BU_Iterator{T <: AbstractRuleNode} <: BottomUpIterator{T} end

function get_initial_bound(iter::Bounded_BU_Iterator{T})::Float64 where T
    error("get_initial_bound not implemented for $(typeof(iter))")
end

function bound_function(iter::Bounded_BU_Iterator{T}, program::T)::Float64 where T
    error("bound_function not implemented for $(typeof(iter))")
end

function combine_bound_function(
    iter::Bounded_BU_Iterator{T}, 
    rule_idx::Int, 
    children_bounds::Vector{Float64}
)::Float64 where T
    error("combine_bound_function not implemented for $(typeof(iter))")
end

function next_bound(
    iter::Bounded_BU_Iterator{T},
    current_bound::Float64
)::Float64 where T
    # Default implementation: increment by 1.0
    return current_bound + 1.0
end

struct Bounded_BU_Bank{T <: AbstractRuleNode} <: BottomUpBank{T}
    bound_symbol_program_map::Dict{Float64, Dict{Symbol, Vector{T}}}
    all_bounds::Vector{Float64} # Keep track of all unique bounds we've seen, in order
end

mutable struct Bounded_BU_Data{T <: AbstractRuleNode} <: BottomUpData{T}
    current_bound::Float64
    unused_rules::Queue{T}
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker{T}}
    rules_populated::Bool # Track whether we've already populated unused_rules for the current bound
end

function BottomUpBank{T}(
    iter::Bounded_BU_Iterator{T}
)::Bounded_BU_Bank{T} where T
    bound_symbol_program_map = Dict{Float64, Dict{Symbol, Vector{T}}}()
    bank = Bounded_BU_Bank{T}(bound_symbol_program_map, Vector{Float64}())
    
    initial_bound = get_initial_bound(iter)
    _initialize_bound!(iter, bank, initial_bound)
    
    return bank
end

function BottomUpData{T}(
    iter::Bounded_BU_Iterator{T}
)::Bounded_BU_Data{T} where T
    initial_bound = get_initial_bound(iter)
    unused_rules = _create_unused_rules(iter, true)  # Start with terminal rules
    
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker{T}} = nothing
    if hasfield(typeof(iter), :obs_equivalence) && iter.obs_equivalence
        @assert hasfield(typeof(iter), :spec) && !isnothing(iter.spec) "If `obs_equivalence` is true, `spec` must not be `nothing`."
        obs_checker = ObservationalEquivalenceChecker{T}()
    end
 
    return Bounded_BU_Data{T}(initial_bound, unused_rules, obs_checker, true)
end

function _initialize_bound!(
    iter::Bounded_BU_Iterator{T},
    bank::Bounded_BU_Bank{T},
    bound::Float64
)::Nothing where T
    bank.bound_symbol_program_map[bound] = Dict{Symbol, Vector{T}}()
    
    # Add bound to our list of known bounds if not already present
    if !(bound in bank.all_bounds)
        push!(bank.all_bounds, bound)
        sort!(bank.all_bounds)
    end
    
    # Initialize program vectors for each symbol
    grammar = get_grammar(iter.solver)
    for type in grammar.types
        bank.bound_symbol_program_map[bound][type] = Vector{T}()
    end
    
    return nothing
end

function _get_first_rule_index(
    node::T
)::Int64 where T <: AbstractRuleNode
    if T <: RuleNode
        return node.ind
    elseif T <: UniformHole
        return findfirst(node.domain)
    else
        error("Unsupported node type: $T")
    end
end

function _create_unused_rules(
    iter::Bounded_BU_Iterator{T},
    terminals::Bool
)::Queue{T} where T
    grammar = get_grammar(iter.solver)
    unused_rules = Queue{T}()

    if T <: RuleNode
        for (rule, is_terminal) in enumerate(grammar.isterminal)
            if is_terminal == terminals
                enqueue!(unused_rules, RuleNode(rule))
            end
        end
    elseif T <: UniformHole
        # Store the rules we need to partition into UniformHoles
        rules::BitVector = grammar.isterminal
        if !terminals
            rules = rules .⊻ BitVector(fill(true, length(rules)))
        end

        symbol_to_rules::Dict{Symbol, BitVector} = grammar.domains
        hole_domains = Vector{BitVector}()
        for (_, rules_for_symbol) in symbol_to_rules
            # Only partition terminal/non-terminal rules (based on `terminals`)
            domain = rules_for_symbol .&& rules
            append!(hole_domains, partition(Hole(domain), grammar))
        end

        for domain in hole_domains
            enqueue!(unused_rules, UniformHole(domain, Vector{UniformHole}()))
        end
    else
        error("Unsupported node type: $T")
    end
    
    return unused_rules
end

function combine!(
    iter::Bounded_BU_Iterator{T},
    bank::Bounded_BU_Bank{T},
    data::Bounded_BU_Data{T}
)::Union{RuleNodeCombinations{T}, Nothing} where T
    grammar = get_grammar(iter.solver)
    max_depth = get_max_depth(iter.solver)
    
    # Check if we've reached max bound (if specified in the solver)
    if hasfield(typeof(iter), :max_bound) && data.current_bound > iter.max_bound
        return nothing
    end
    
    while true
        # If we need to populate rules for the current bound and haven't yet
        if !data.rules_populated
            # Add the current bound to the bank if it doesn't exist
            if !(data.current_bound in bank.all_bounds)
                _initialize_bound!(iter, bank, data.current_bound)
            end
            
            # Add non-terminals to the unused_rules queue
            data.unused_rules = _create_unused_rules(iter, false)
            data.rules_populated = true
        end
        
        # Check if we've exhausted all rules for the current bound
        if isempty(data.unused_rules)
            # Move to the next bound
            data.current_bound = next_bound(iter, data.current_bound)
            data.rules_populated = false
            
            # Check if we've reached max bound (if specified in the solver)
            if data.current_bound > max_depth
                return nothing
            end
            
            continue
        end
        
        # Get the next rule to expand
        rule = dequeue!(data.unused_rules)
        rule_idx = _get_first_rule_index(rule)
        childtypes = grammar.childtypes[rule_idx]
        
        # Create children lists for each child type that could form a program with the current bound
        children_lists = Vector{Vector{T}}()
        
        for child_type in childtypes
            # For each child type, we need all programs that could be used
            # to form a program with our target bound
            child_programs = Vector{T}()
            
            # Go through all existing bounds
            for bound in bank.all_bounds
                # Skip bounds greater than or equal to current
                if bound >= data.current_bound
                    continue
                end
                
                # For now just collect all programs of smaller bounds
                # (a more efficient implementation would filter based on combine_bound_function)
                append!(child_programs, bank.bound_symbol_program_map[bound][child_type])
            end
            
            # If we have no valid child programs, we can't form any valid combinations
            if isempty(child_programs)
                return combine!(iter, bank, data)  # Try the next rule
            end
            
            push!(children_lists, child_programs)
        end
        
        return RuleNodeCombinations{T}(rule, children_lists)
    end
end

function is_valid(
    iter::Bounded_BU_Iterator{T},
    program::T,
    data::Bounded_BU_Data{T}
)::Bool where T
    # Check if the program's bound matches the current bound we're exploring
    program_bound = bound_function(iter, program)
    if abs(program_bound - data.current_bound) > 1e-10  # Float comparison with tolerance
        return false
    end

    # Check observational equivalence if enabled
    if !isnothing(data.obs_checker)
        return is_new_program!(data.obs_checker, program, get_grammar(iter.solver), iter.spec)
    end

    return true
end

function add_to_bank!(
    iter::Bounded_BU_Iterator{T},
    bank::Bounded_BU_Bank{T},
    program::T
)::Nothing where T
    grammar = get_grammar(iter.solver)
    program_bound = bound_function(iter, program)
    
    # Ensure the bound exists in our bank
    if !(program_bound in bank.all_bounds)
        _initialize_bound!(iter, bank, program_bound)
    end
    
    # Add the program to the appropriate collection
    symbol = grammar.types[_get_first_rule_index(program)]
    push!(bank.bound_symbol_program_map[program_bound][symbol], program)
    
    return nothing
end