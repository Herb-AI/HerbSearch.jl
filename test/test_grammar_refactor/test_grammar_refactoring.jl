# All tests related to the RefactorExt module for grammar refactoring

@testset "Grammar Optimiser with ASP (RecatorExt module tests)" verbose=true begin
    include("test_analyze_compressions.jl")
    include("test_extend_grammar.jl")
    include("test_grammar_refactor_integration.jl")
    include("test_parse_input.jl")
    include("test_parse_output.jl")
    include("test_convert_subtrees_to_json.jl")
end
