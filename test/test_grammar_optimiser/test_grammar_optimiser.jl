@testset "Grammar Optimiser with ASP" verbose=true begin
    include("test_analyze_compressions.jl")
    include("test_extend_grammar.jl")
    include("test_grammar_optimiser_integration.jl")
    include("test_parse_input.jl")
    include("test_parse_output.jl")
    include("test_parse_subtrees_to_json.jl")
end
