"""
TODO: add documentation
"""
struct RuleNodeCombinations{T <: AbstractRuleNode}
    root::T
    children_lists::Vector{Vector{T}} # TODO: make outer array of fixed size.
end