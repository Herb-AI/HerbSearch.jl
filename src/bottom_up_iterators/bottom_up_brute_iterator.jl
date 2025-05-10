Base.@doc """
    @programiterator BUBruteIterator(spec::Union{Nothing, Problem{Vector{IOExample}}}=nothing, obs_equivalence::Bool=false) <: BottomUpIterator{RuleNode})

TODO
""" BUBruteIterator
@programiterator BUBruteIterator(
    distance_function::Function,
    spec::Vector{<:IOExample},
    helper_iterator::ProgramIterator,
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
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)
    remaining_terminals::Queue{RuleNode} = _create_unused_rules(iter, rule -> grammar.isterminal[rule])
    obs_checker = iter.obs_equivalence ? ObservationalEquivalenceChecker{RuleNode}() : nothing
    _build_brute_grammar(iter)
    return BUBruteData(remaining_terminals, [], obs_checker)
end

function combine!(
    iter::BUBruteIterator,
    bank::BUBruteBank,
    data::BUBruteData
)::Union{RuleNodeCombinations{RuleNode}, Nothing}
    grammar::ContextSensitiveGrammar = get_grammar(iter.solver)

    # This is checked in a loop to exit in the case the grammar has no nonterminals.
    while isempty(data.unused_rules)
        if isempty(bank.search_frontier)
            return nothing
        end

        data.current_expanded_childlist = [[dequeue!(bank.search_frontier)]]
        data.unused_rules = _create_unused_rules(iter, rule -> length(grammar.childtypes[rule]) == 1 && grammar.childtypes[rule][1] == (_get_startsymbol(iter)))
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
    enqueue!(bank.search_frontier, program => _compute_distance(iter, program))
    return nothing
end

function _get_startsymbol(
    iter::BUBruteIterator
)::Symbol
    root = iter.solver.state.tree
    grammar = get_grammar(iter.solver)

    @assert(root isa Hole, "The root of the solver's initial state is assumed to be a Hole.")
    return grammar.types[findfirst(root.domain)]
end

function _build_brute_grammar(
    iter::BUBruteIterator
)
    grammar = get_grammar(iter.solver)
    symbol2rulenodes = Dict{Symbol, Vector{RuleNode}}()
    for type ∈ grammar.types
        symbol2rulenodes[type] = []
    end

    programs = collect(iter.helper_iterator)
    for program ∈ programs
        program_type = grammar.types[program.ind]
        push!(symbol2rulenodes[program_type], program)
    end

    startsymbol = _get_startsymbol(iter)
    for rule ∈ 1:length(grammar.rules)
        for (i, childtype) ∈ enumerate(grammar.childtypes[rule])
            if childtype != startsymbol
                continue
            end
            children_lists::Vector{Vector{AbstractRuleNode}} = map(symbol -> symbol2rulenodes[symbol], grammar.childtypes[rule])
            children_lists[i] = [Hole(get_domain(grammar, startsymbol))]

            for children ∈ Iterators.product(children_lists...)
                add_rule!(grammar, RuleNode(rule, collect(children)))
            end
        end
    end
end

function _create_unused_rules(
    iter::BUBruteIterator,
    predicate::Function # Int -> Bool
)::Queue{RuleNode}
    grammar = get_grammar(iter.solver)
    unused_rules = Queue{RuleNode}()

    for rule in 1:length(grammar.rules)
        if predicate(rule)
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