@testitem "Doctests" begin
    using Documenter: DocMeta, doctest
    import HerbCore, HerbConstraints, HerbGrammar

    DocMeta.setdocmeta!(HerbSearch, :DocTestSetup, :(using HerbCore,
            HerbConstraints, HerbGrammar, HerbSearch); recursive=true)
    doctest(HerbSearch; manual=false)
end
