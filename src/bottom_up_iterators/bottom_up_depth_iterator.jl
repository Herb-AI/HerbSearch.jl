Base.@doc """
    @programiterator BUDepthIterator(problem::Union{Nothing, Problem{Vector{IOExample}}}=nothing, obs_equivalence::Bool=false) <: BottomUpIterator

Implementation of the `BottomUpIterator`. Iterates through complete programs in increasing order of their depth.
""" BUDepthIterator
@programiterator BUDepthIterator(
    problem::Any = nothing,         # TODO define a specific type for this Problem{Vector{IOExample}}
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
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)
    depth_symbol_program_map::Dict{Depth, Dict{Symbol, Vector{RuleNode}}} = Dict{Depth, Dict{Symbol, Vector{RuleNode}}}()

    depth_symbol_program_map[1] = Dict{Symbol, Vector{RuleNode}}()

    for symbol ∈ grammar.types
        depth_symbol_program_map[1][symbol] = Vector{RuleNode}()
    end

    return BUDepthBank(depth_symbol_program_map)
end

"""
    struct BUDepthData <: BottomUpData

TODO: Explain each field of this class.
"""
mutable struct BUDepthData <: BottomUpData
    current_depth::Depth
    rules_queue::Queue{Int}
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker}
    is_terminal_phase::Bool
end

BottomUpData(iter::BUDepthIterator) = BUDepthData(iter)

"""
    BUDepthData(iter::BUDepthIterator)::BUDepthData
"""
function BUDepthData(
    iter::BUDepthIterator
)::BUDepthData
    terminal_rules = [i for (i, is_term) in enumerate(get_grammar(iter.solver).isterminal) if is_term]

    terminals_queue = Queue{Int}()

    for rule in terminal_rules
        enqueue!(terminals_queue, rule)
    end

    obs_checker::Union{Nothing, ObservationalEquivalenceChecker} = iter.obs_equivalence ? ObservationalEquivalenceChecker() : nothing

    return BUDepthData(1, terminals_queue, obs_checker, true)
end



function combine!(
    iter::BUDepthIterator,
    data::BUDepthData,
    bank::BUDepthBank
)::Union{RuleNodeCombinations, Nothing}
grammar = get_grammar(iter.solver)
    max_depth = get_max_depth(iter.solver)

    while true
        # Queue empty -> end or try next depth 
        if isempty(data.rules_queue)
            println("HHELLOOOOWWW EMPTYYYYYY")
            if data.current_depth >= max_depth
                return nothing
            end
            data.current_depth += 1
            data.is_terminal_phase = false

            non_terminal_rules = [i for (i, is_term) in enumerate(grammar.isterminal) if !is_term]
            data.rules_queue = Queue{Int}()
            for rule in non_terminal_rules
                enqueue!(data.rules_queue, rule)
            end
            continue
        end

        rule = dequeue!(data.rules_queue)
        
        if data.is_terminal_phase
            println("HELLOOOOWW TERMINAL PHASE")
            return RuleNodeCombinations(rule, Vector{Vector{RuleNode}}())
        else
            println("HELLOOOOWW NON TERMINAL PHASE")
            child_types = grammar.childtypes[rule]
            children_lists = Vector{Vector{RuleNode}}()
            for child_type in child_types
                child_programs = Vector{RuleNode}()


                for d in 1:(data.current_depth - 1)
                    # if haskey(bank.depth_symbol_program_map, d)
                        append!(child_programs, get(bank.depth_symbol_program_map[d], child_type, Vector{RuleNode}()))
                    # end
                end


                if isempty(child_programs)
                    break
                end
                push!(children_lists, child_programs)
            end
            if length(children_lists) == length(child_types)
                return RuleNodeCombinations(rule, children_lists)
            end
        end
    end
end


function is_valid(
    iter::BUDepthIterator,
    program::RuleNode,
    data::BUDepthData
)::Bool
    
    if isnothing(data.obs_checker) 
        return is_new_program!(data.obs_checker, program, get_grammar(iter.solver), iter.problem)
    end

    return true 
end



function add_to_bank!(
    iter::BUDepthIterator,
    bank::BUDepthBank,
    program::RuleNode
)::Nothing
    grammar = get_grammar(iter.solver)
    program_depth = get_depth(program)
    return_type = grammar.types[program.ind]

    if !haskey(bank.depth_symbol_program_map, program_depth)
        bank.depth_symbol_program_map[program_depth] = Dict{Symbol, Vector{RuleNode}}()
        for symbol ∈ grammar.types
            bank.depth_symbol_program_map[program_depth][symbol] = Vector{RuleNode}()
        end
    end

    push!(bank.depth_symbol_program_map[program_depth][return_type], program)
end