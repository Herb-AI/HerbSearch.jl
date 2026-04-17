using HerbCore, HerbGrammar, HerbSearch
using MLStyle, DataStructures

include("analyser.jl")

int_grammar = @cfgrammar begin
    Int = 1 | 2 | 3 | 4
    Int = - Int
    Int = Int + Int
    Int = Int * Int
end

prop_grammar = deepcopy(int_grammar)
merge_grammars!(prop_grammar, @cfgrammar begin
    Bool = Int == Int
    Bool = Int != Int
    Bool = Int >  Int
    Bool = Int >= Int
    Bool = Int <  Int
    Bool = Int <= Int
    Int  = _arg_1
end)

interp = (rulenode, args) -> begin
    cs = [interp(child, args) for child in get_children(rulenode)]

    @match get_rule(rulenode) begin
        1 => 1
        2 => 2
        3 => 3
        4 => 4
        5 => - cs[1]
        6 => cs[1] + cs[2]
        7 => cs[1] * cs[2]
        8 => cs[1] == cs[2]
        9 => cs[1] != cs[2]
        10 => cs[1] >  cs[2]
        11 => cs[1] >= cs[2]
        12 => cs[1] <  cs[2]
        13 => cs[1] <= cs[2]
        14 => args[:_arg_1]
    end
end

# property_scores = score_properties(;
#     program_grammar = int_grammar,
#     program_starting_symbol = :Int,
#     max_program_depth = 2,
#     property_grammar = prop_grammar,
#     property_starting_symbol = :Bool,
#     max_property_depth = 2,
#     max_extension_depth = 2,
# )

# show_scored_properties(property_scores)

scores = score_property_extension_pairs(;
    program_grammar = int_grammar,
    program_starting_symbol = :Int,
    max_program_depth = 2,
    property_grammar = prop_grammar,
    property_starting_symbol = :Bool,
    max_property_depth = 2,
    max_extension_depth = 1,
)

show_scored_property_extension_pairs(scores, prop_grammar, :Int)