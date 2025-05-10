Base.@doc """
    @programiterator BUBruteIterator(spec::Union{Nothing, Problem{Vector{IOExample}}}=nothing, obs_equivalence::Bool=false) <: BottomUpIterator{RuleNode})

TODO
""" BUBruteIterator
@programiterator BUBruteIterator(
    distance_function::Function, #TODO: is there any way to make this more specific?
    spec::Vector{<:IOExample},
    obs_equivalence::Bool = false
) <: BottomUpIterator{RuleNode}

struct BUBruteBank <: BottomUpBank{RuleNode}
    search_frontier::PriorityQueue{RuleNode, Float64}
end

BottomUpBank{RuleNode}(iter::BUBruteIterator) = BUBruteBank(iter)

function BUBruteBank(
    ::BUBruteIterator
)::BUBruteBank
    return BUBruteBank(PriorityQueue{RuleNode, Float64}())
end

mutable struct BUBruteData <: BottomUpData{RuleNode}
    unused_rules::Queue{RuleNode}
    current_expanded_childlist::Vector{Vector{RuleNode}}
    obs_checker::Union{Nothing, ObservationalEquivalenceChecker{RuleNode}}
end

BottomUpData{T}(iter::BUBruteIterator) where T = BUBruteData(iter)

function BUBruteData(
    iter::BUBruteIterator
)::BUBruteData
    remaining_terminals::Queue{RuleNode} = _create_unused_rules(iter, true)
    obs_checker = iter.obs_equivalence ? ObservationalEquivalenceChecker{RuleNode}() : nothing
    return BUBruteData(remaining_terminals, [], obs_checker)
end

function combine!(
    iter::BUBruteIterator,
    bank::BUBruteBank,
    data::BUBruteData
)::Union{RuleNodeCombinations{RuleNode}, Nothing}
    # This is checked in a loop to exit in the case the grammar has no nonterminals.
    while isempty(data.unused_rules)
        if isempty(bank.search_frontier)
            return nothing
        end

        data.current_expanded_childlist = [[dequeue!(bank.search_frontier)]]
        data.unused_rules = _create_unused_rules(iter, false)
    end

    root::RuleNode = dequeue!(data.unused_rules)
    return RuleNodeCombinations(root, data.current_expanded_childlist)
end


function is_valid(
    iter::BUBruteIterator,
    program::RuleNode,
    data::BUBruteData
)::Bool
    if isnothing(data.obs_checker)
        return true
    end

    return is_new_program!(data.obs_checker, program, get_grammar(iter.solver), iter.spec)
end

function add_to_bank!(
    iter::BUBruteIterator,
    bank::BUBruteBank,
    program::RuleNode
)::Nothing
    println(rulenode2expr(program, get_grammar(iter.solver)))
    enqueue!(bank.search_frontier, program => _compute_distance(iter, program))
    return nothing
end

function _create_unused_rules(
    iter::BUBruteIterator,
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

function _compute_distance(
    iter::BUBruteIterator,
    program::RuleNode
)::Float64
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

    real_outputs::Vector{Any} = map(example -> example.out, iter.spec)
    obtained_outputs::Vector{Any} = execute_on_input(grammar, program, map(example -> example.in, iter.spec))
    distances::Vector{Float64} = map(o -> iter.distance_function(o[1], o[2]), zip(real_outputs, obtained_outputs))

    return sum(distances) / length(distances)
end