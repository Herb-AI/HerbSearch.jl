using Logging
using Observables
using Sockets

"""A one-shot HTTP GET against the inspector's loopback server."""
function _inspect_http_get(port::Integer, target::AbstractString)
    sock = Sockets.connect(Sockets.localhost, port)
    write(sock, "GET $target HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n")
    response = read(sock, String)
    close(sock)
    split_at = findfirst("\r\n\r\n", response)
    isnothing(split_at) && return (response, "")
    return (response[1:first(split_at)-1], response[last(split_at)+1:end])
end

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

    _traced_iterator(; max_depth=3) =
        BFSIterator(; solver=HerbSearch.tracing_generic_solver(_grammar(), :Int; max_depth=max_depth))

    @testset "tracing does not change the search" begin
        g = _grammar()
        expected = [freeze_state(p) for p ∈ BFSIterator(g, :Int; max_depth=3)]

        solver = HerbSearch.tracing_generic_solver(g, :Int; max_depth=3)
        traced = [freeze_state(p) for p ∈ BFSIterator(; solver=solver)]

        @test length(traced) == length(expected)
        @test all(a == b for (a, b) ∈ zip(traced, expected))
    end

    @testset "the search is lazy" begin
        insp = Inspection(_traced_iterator())
        try
            # only the solver construction has been recorded; the iterator has not started
            @test isempty(insp.steps)
            constructed = length(insp.events)
            @test constructed > 0
            @test all(e.step == 0 for e ∈ insp.events)

            # one event at a time, without completing a program
            advance!(insp; events=1)
            @test length(insp.events) == constructed + 1
            @test isempty(insp.steps)

            advance!(insp; events=3)
            @test length(insp.events) == constructed + 4
            @test isempty(insp.steps)

            # ... and the search really is suspended in the middle of the run
            @test !insp.finished

            advance!(insp; programs=1)
            @test length(insp.steps) == 1
            @test insp.steps[1].expr == "1"

            advance!(insp; programs=2)
            @test length(insp.steps) == 3
            @test [s.expr for s ∈ insp.steps] == ["1", "x", "x + 1"]
            @test any(e -> e.step > 0, insp.events)
        finally
            close(insp)
        end
    end

    @testset "pulling to the end" begin
        insp = Inspection(_traced_iterator(max_depth=2))
        try
            run_to_end!(insp)
            @test insp.finished
            @test [s.expr for s ∈ insp.steps] ==
                  [string(rulenode2expr(freeze_state(p), _grammar())) for p ∈ BFSIterator(_grammar(), :Int; max_depth=2)]
            # advancing a finished inspection is a no-op
            n = length(insp.events)
            advance!(insp; programs=5)
            @test length(insp.events) == n
        finally
            close(insp)
        end
    end

    @testset "the search can run on its own thread" begin
        insp = Inspection(_traced_iterator(max_depth=2); buffer=8, spawn=true)
        try
            run_to_end!(insp)
            @test insp.finished
            @test [s.expr for s ∈ insp.steps] ==
                  [string(rulenode2expr(freeze_state(p), _grammar())) for p ∈ BFSIterator(_grammar(), :Int; max_depth=2)]
            @test sort([e.index for e ∈ insp.events]) == 1:length(insp.events)
        finally
            close(insp)
        end
    end

    @testset "events are complete and chronological" begin
        insp = record_inspection(_traced_iterator(); max_programs=8)
        try
            @test length(insp.steps) == 8
            events = chronological(insp)
            @test [e.index for e ∈ events] == 1:length(events)
            @test :generic ∈ [e.solver for e ∈ events]
            @test :uniform ∈ [e.solver for e ∈ events]

            props = filter(e -> e.kind === :propagate, events)
            @test !isempty(props)
            @test any(e -> !isempty(e.changes), props)
            @test any(e -> e.name == "LocalForbidden", props)
            @test all(!isnothing(e.before) && !isnothing(e.after) for e ∈ props)
            # constraint propagation only ever shrinks domains
            for e ∈ props, c ∈ e.changes
                @test isempty(c.added)
            end
        finally
            close(insp)
        end
    end

    @testset "listeners fire on every advance" begin
        insp = Inspection(_traced_iterator())
        try
            calls = Int[]
            on_update!(i -> push!(calls, length(i.events)), insp)
            advance!(insp; events=1)
            advance!(insp; events=1)
            @test length(calls) == 2
            @test calls[2] == calls[1] + 1
        finally
            close(insp)
        end
    end

    @testset "events can be routed through the logging system" begin
        # `test_helpers.jl` disables logging suite wide, which would swallow the `@debug`
        # messages this test is about; lift it for the duration and put it back afterwards.
        Logging.disable_logging(Logging.BelowMinLevel)
        try
            logger = Test.TestLogger(min_level=Logging.Debug)
            insp = Logging.with_logger(logger) do
                i = Inspection(BFSIterator(; solver=HerbSearch.tracing_generic_solver(
                    _grammar(), :Int; max_depth=3, trace=HerbSearch.Trace(logging=true))))
                advance!(i; programs=1)
                return i
            end
            close(insp)
            records = filter(r -> r.group === :herb_inspect, logger.logs)
            @test !isempty(records)
            @test all(haskey(Dict(r.kwargs), :changes) for r ∈ records)
            @test any(r -> Dict(r.kwargs)[:kind] === :propagate, records)
        finally
            Logging.disable_logging(Logging.LogLevel(1))
        end
    end

    @testset "an unconstrained grammar works too" begin
        g = @csgrammar begin
            Int = 1
            Int = Int + Int
        end
        insp = record_inspection(BFSIterator(; solver=HerbSearch.tracing_generic_solver(g, :Int; max_depth=3));
            max_programs=3)
        @test length(insp.steps) == 3
        close(insp)
    end

    @testset "static page is self contained" begin
        file = joinpath(mktempdir(), "inspect.html")
        insp = @inspect BFSIterator(_grammar(), :Int; max_depth=3) live = false max_programs = 5 open_browser = false output = file
        @test isfile(file)
        html = read(file, String)
        @test occursin("<!DOCTYPE html>", html)
        @test !occursin("/*__DATA__*/", html)   # the payload was substituted
        @test occursin("const LIVE = null", html) # a snapshot never calls home
        @test !occursin("http://", html)          # no external resources
        @test insp.file == file
        close(insp)
    end

    @testset "the live server drives the search" begin
        insp = @inspect BFSIterator(_grammar(), :Int; max_depth=3) open_browser = false prefetch = 0
        try
            server = insp.server
            @test server isa HerbSearch.InspectServer
            @test startswith(server.url, "http://127.0.0.1:")
            @test isempty(insp.steps)

            status, body = _inspect_http_get(server.port, "/$(server.token)/")
            @test occursin("200 OK", status)
            @test occursin("<!DOCTYPE html>", body)
            @test occursin("\"base\"", body)     # live mode is configured

            # the page asks for one program: the suspended search runs exactly that far
            status, body = _inspect_http_get(server.port,
                "/$(server.token)/pull?programs=1&haveEvents=0&haveSteps=0")
            @test occursin("200 OK", status)
            @test occursin("\"totalSteps\":1", body)
            @test length(insp.steps) == 1

            # a bad token is refused
            status, _ = _inspect_http_get(server.port, "/wrongtoken/pull?programs=1")
            @test occursin("404", status)
            @test length(insp.steps) == 1
        finally
            close(insp)
        end
    end

    @testset "Observables front ends can subscribe" begin
        insp = Inspection(_traced_iterator())
        try
            obs = observe(insp)
            @test obs.latest isa Observable
            seen = Any[]
            on(e -> push!(seen, e), obs.latest)

            advance!(insp; events=1)
            @test length(seen) == 1
            @test seen[1] === last(insp.events)
            @test length(obs.events[]) == length(insp.events)
            @test [e.index for e ∈ obs.events[]] == 1:length(insp.events)

            advance!(insp; programs=1)
            @test !isempty(obs.steps[])
            @test obs.finished[] == false
        finally
            close(insp)
        end
    end

    @testset "snapshots and diffs" begin
        before = HerbSearch.take_snapshot(UniformHole(BitVector([1, 1, 0, 0]), []))
        after = HerbSearch.take_snapshot(RuleNode(2))
        changes = HerbSearch.diff_snapshots(before, after)
        @test length(changes) == 1
        @test changes[1].kind === :fill
        @test changes[1].removed == [1]
        @test isempty(HerbSearch.diff_snapshots(before, before))
    end
end
