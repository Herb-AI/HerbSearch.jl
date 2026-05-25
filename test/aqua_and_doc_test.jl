@testitem "Aqua" setup = [TestSetup] begin
    using Aqua

    @testset "Aqua" begin
        Aqua.test_all(
            HerbSearch,
            piracies=(treat_as_own=[RuleNode, AbstractGrammar],),
        )
    end
end

@testitem "Doctest" setup = [TestSetup] begin
    using Documenter: DocMeta, doctest

    DocMeta.setdocmeta!(
        HerbSearch,
        :DocTestSetup,
        :(using HerbCore, HerbConstraints, HerbGrammar, HerbSearch),
        recursive=true,
    )

    @testset "Doctest" begin
        doctest(HerbSearch; manual=false)
    end
end
