using HerbCore, HerbGrammar, HerbSearch
using MLStyle, DataStructures

include("analyser.jl")

string_grammar = @cfgrammar begin
    String = "......" | ",,,,,," | "." | ","
    String = concat(String, String)
    String = first_half(String)
    String = last_half(String)
end

prop_grammar = deepcopy(string_grammar)
merge_grammars!(prop_grammar, @cfgrammar begin
    Bool = String == String
    Bool = String != String
    Bool = contains(String, String)
    Bool = starts_with(String, String)
    Bool = ends_with(String, String)
    Bool = !Bool
    String  = _arg_1
end)

interp = (rulenode, args) -> begin
    cs = [interp(child, args) for child in get_children(rulenode)]

    @match get_rule(rulenode) begin
        1 => "......"
        2 => ",,,,,,"
        3 => "."
        4 => ","
        5 => cs[1] * cs[1]
        6 => cs[1][begin:max(div(end, 2), 1)]
        7 => cs[1][div(end, 2)+1:end]
        8 => cs[1] == cs[2]
        9 => cs[1] != cs[2]
        10 => occursin(cs[2], cs[1])
        11 => startswith(cs[1], cs[2])
        12 => endswith(cs[1], cs[2])
        13 => !cs[1]
        14 => args[:_arg_1]
    end
end

property_scores = score_properties(;
    program_grammar = string_grammar,
    program_starting_symbol = :String,
    max_program_depth = 2,
    property_grammar = prop_grammar,
    property_starting_symbol = :Bool,
    max_property_depth = 2,
    max_extension_depth = 2,
)

show_scored_properties(property_scores)