"""
TODO: add documentation
"""
struct RuleNodeCombinations
    root::AbstractRuleNode
    children_lists::Vector{Vector{AbstractRuleNode}} # TODO: make outer array of fixed size.
end