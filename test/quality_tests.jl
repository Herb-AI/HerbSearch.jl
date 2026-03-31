@testitem "Quality tests" begin
    using Aqua
    using HerbCore: RuleNode, AbstractGrammar

    @testset "Aqua" Aqua.test_all(
        HerbSearch,
        piracies=(treat_as_own=[RuleNode, AbstractGrammar],),
    )
end
