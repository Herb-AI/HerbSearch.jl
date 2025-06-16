
using Markdown
using InteractiveUtils
using Random
using Dates
include("../ext/RefactorExt/RefactorExt.jl")
using .RefactorExt
include("../src/HerbSearch.jl")
using HerbCore, HerbGrammar, .HerbSearch, HerbSpecification, HerbBenchmarks, HerbConstraints
include("utils.jl")


function make_bitvector(true_indices::Vector{Int}, len::Int)
    bv = falses(len)
    bv[true_indices] .= true
    return bv
end

function constraint_sequence_of_two(grammar::ContextSensitiveGrammar, rule_1::Int, rule_2::Int)
    addconstraint!(grammar, Forbidden(
        RuleNode(3, [
            RuleNode(4, [RuleNode(rule_1)]), 
            RuleNode(3, [
                RuleNode(4, [RuleNode(rule_2)]), 
                VarNode(:a)])])))
end

function if_cond_if_branch(grammar::ContextSensitiveGrammar, cond::Int, rule::Int)
    addconstraint!(grammar, Forbidden(
        RuleNode(11, [
            RuleNode(cond), 
            RuleNode(2, [RuleNode(4, [RuleNode(rule)])]), 
            VarNode(:a)])))

    addconstraint!(grammar, Forbidden(
        RuleNode(11, [
            RuleNode(cond), 
            RuleNode(3, [RuleNode(4, [RuleNode(rule)]), VarNode(:a)]), 
            VarNode(:b)])))
end

function if_cond_else_branch(grammar::ContextSensitiveGrammar, cond::Int, rule::Int)
    addconstraint!(grammar, Forbidden(
        RuleNode(11, [
            RuleNode(cond), 
            VarNode(:a),
            RuleNode(2, [RuleNode(4, [RuleNode(rule)])])])))

    addconstraint!(grammar, Forbidden(
        RuleNode(11, [
            RuleNode(cond), 
            VarNode(:b),
            RuleNode(3, [RuleNode(4, [RuleNode(rule)]), VarNode(:a)])])))
end

function get_constrained_string_grammar()
    benchmark = HerbBenchmarks.String_transformations_2020
    problem_grammar_pairs = get_all_problem_grammar_pairs(benchmark)
    g = deepcopy(problem_grammar_pairs[1].grammar)

    constraint_sequence_of_two(g, 6, 7) # Forbids moveRight() -> moveLeft()
    constraint_sequence_of_two(g, 7, 6) # Forbids moveLeft() -> moveRight()
    constraint_sequence_of_two(g, 8, 9) # Forbids makeUppercase() -> makeLowercase()
    constraint_sequence_of_two(g, 9, 8) # Forbids makeLowercase() -> makeUppercase()

    # Forbid if-statements with a negative condition (notAtStart, isNotSpace, etc.)
    addconstraint!(g, Forbidden(
        RuleNode(11, [
            DomainRuleNode(make_bitvector([14,16,18,20,22,24,26], 26)), 
            VarNode(:a), 
            VarNode(:b)])))

    # Forbid if statements with equal branches
    addconstraint!(g, Forbidden(
        RuleNode(11, [
            VarNode(:a), 
            VarNode(:b), 
            VarNode(:b)])))

    # Forbid making an uppercase character an uppercase
    if_cond_if_branch(g, 19, 8)

    # Forbid making an lowercase character an lowercase
    if_cond_else_branch(g, 19, 9)

    # Forbid moving to the right at the right
    if_cond_if_branch(g, 13, 6)

    # Forbid moving to the left at the left
    if_cond_if_branch(g, 14, 7)

    return g
end


# benchmark = HerbBenchmarks.String_transformations_2020
# problem_grammar_pairs = get_all_problem_grammar_pairs(benchmark)
# grammar_1 = deepcopy(problem_grammar_pairs[1].grammar)

# iterator_1 = HerbSearch.DFSIterator(grammar_1, :Sequence, max_depth=6)
# size_1 = length(iterator_1)
# println("Length before: $size_1")

# grammar_2 = get_constrained_string_grammar()
# iterator_2 = HerbSearch.DFSIterator(grammar_2, :Sequence, max_depth=6)
# size_2 = length(iterator_2)
# println("Length after: $size_2")