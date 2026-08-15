@testset verbose = true "Inspector" begin

    function _grammar()
        g = @csgrammar begin
            Int = 1
            Int = x
            Int = Int + Int
            Int = Int * Int
        end
        addconstraint!(g, Forbidden(RuleNode(3, [RuleNode(1), VarNode(:a)])))
        addconstraint!(g, Ordered(RuleNode(4, [VarNode(:a), VarNode(:b)]), [:a, :b]))
        return g
    end

    @testset "tracing does not change the search" begin
        g = _grammar()
        expected = [freeze_state(p) for p ∈ BFSIterator(g, :Int; max_depth=3)]

        solver = HerbSearch.tracing_generic_solver(g, :Int; max_depth=3)
        traced = [freeze_state(p) for p ∈ BFSIterator(; solver=solver)]

        @test length(traced) == length(expected)
        @test all(a == b for (a, b) ∈ zip(traced, expected))
    end

    @testset "a run is recorded" begin
        g = _grammar()
        insp = @inspect BFSIterator(g, :Int; max_depth=3) max_programs = 8 open_browser = false

        @test insp isa HerbSearch.Inspection
        @test length(insp.steps) == 8
        @test all(!isempty(s.expr) for s ∈ insp.steps)
        # every step knows the state of the search queue
        @test all(!isempty(s.queue) for s ∈ insp.steps[1:end-1])

        events = insp.trace.events
        @test !isempty(events)
        # both solvers are traced
        @test :generic ∈ [e.solver for e ∈ events]
        @test :uniform ∈ [e.solver for e ∈ events]
        # constraint propagation is recorded, with deductions attached
        props = filter(e -> e.kind === :propagate, events)
        @test !isempty(props)
        @test any(e -> !isempty(e.changes), props)
        @test any(e -> e.name == "LocalForbidden", props)
        # every event has a before/after snapshot and a step it belongs to
        @test all(!isnothing(e.before) && !isnothing(e.after) for e ∈ props)
        @test all(e.step >= 0 for e ∈ events)
        # deductions only ever shrink domains
        for e ∈ props, c ∈ e.changes
            @test isempty(c.added)
        end
    end

    @testset "an unconstrained grammar works too" begin
        g = @csgrammar begin
            Int = 1
            Int = Int + Int
        end
        insp = @inspect BFSIterator(g, :Int; max_depth=3) max_programs = 3 open_browser = false
        @test length(insp.steps) == 3
    end

    @testset "html output is self contained" begin
        g = _grammar()
        file = joinpath(mktempdir(), "inspect.html")
        insp = @inspect BFSIterator(g, :Int; max_depth=3) max_programs = 5 open_browser = false output = file
        @test isfile(file)
        html = read(file, String)
        @test occursin("<!DOCTYPE html>", html)
        @test !occursin("/*__DATA__*/", html)      # the payload was substituted
        @test !occursin("http://", html)           # no external resources
        @test insp.file == file
    end

    @testset "snapshots and diffs" begin
        g = _grammar()
        before = HerbSearch.take_snapshot(UniformHole(BitVector([1, 1, 0, 0]), []))
        after = HerbSearch.take_snapshot(RuleNode(2))
        changes = HerbSearch.diff_snapshots(before, after)
        @test length(changes) == 1
        @test changes[1].kind === :fill
        @test changes[1].removed == [1]
        @test isempty(HerbSearch.diff_snapshots(before, before))
    end
end
