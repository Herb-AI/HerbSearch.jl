abstract type AbstractRuleNodeIterator end

mutable struct RuleNodeIterator <: AbstractRuleNodeIterator
    rulenode::RuleNode
    first_iteration::Bool
end

RuleNodeIterator(rulenode::RuleNode) = RuleNodeIterator(rulenode, true)

function Base.iterate(
    iter::RuleNodeIterator
)::Union{RuleNode, Nothing}
    if iter.first_iteration
        iter.first_iteration = false
        return iter.rulenode
    end
    return nothing
end

mutable struct UniformIteratorAdapter <: AbstractRuleNodeIterator
    uniform_iterator::UniformIterator
end

function UniformIteratorAdapter(
    uniform_tree::UniformHole,
    grammar::ContextSensitiveGrammar
)::UniformIteratorAdapter
    solver = UniformSolver(grammar, copy(uniform_tree))
    uniform_iterator = UniformIterator(solver, nothing)
    return UniformIteratorAdapter(uniform_iterator)
end

function Base.iterate(
    iter::UniformIteratorAdapter
)::Union{RuleNode, Nothing}
    rulenode = next_solution!(iter.uniform_iterator)
    if isnothing(rulenode)
        return nothing
    end

    return freeze_state(rulenode)
end

create_abstract_rulenode_iterator(
    rulenode::RuleNode,
    ::ContextSensitiveGrammar
) = RuleNodeIterator(rulenode)

create_abstract_rulenode_iterator(
    uniform_tree::UniformHole,
    grammar::ContextSensitiveGrammar
) = UniformIteratorAdapter(uniform_tree, grammar)