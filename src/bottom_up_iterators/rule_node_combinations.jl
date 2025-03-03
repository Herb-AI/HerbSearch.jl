"""
TODO: add documentation
"""
struct RuleNodeCombinations
    rule::Int
    children_lists::Vector{Vector{RuleNode}} # TODO: make outer array of fixed size.
end