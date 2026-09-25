using BenchmarkTools: @benchmarkable, BenchmarkGroup
using HerbSearch: CostBUSIterator, compositions
using HerbGrammar: @csgrammar
using HerbCore: RuleNode

function bench_compositions()
    suite = BenchmarkGroup(["bottom-up"])

    for (n, k) in [(25, 10), (5, 2), (5, 3), (6, 4)]
        c = compositions(n, k)
        suite[(n, k)] = @benchmarkable foreach(identity, $c)
    end

    return suite
end

function bench_cost_bus()
    suite = BenchmarkGroup(["bottom-up", "cost-based"])
    g_oe = @csgrammar begin
        Int = x
        Int = 0
        Int = Int + Int
    end
    costs_oe = [1, 1, 1]
    inputs = [1, 2, 3]

    function ev(p, x)
        p.ind == 1 && return x
        p.ind == 2 && return 0
        return ev(p.children[1], x) + ev(p.children[2], x)
    end

    function eval_prog(prog::RuleNode, inputs)
        return ev.((prog,), inputs)
    end
    eval_prog(i) = Base.Fix2(eval_prog, i)

    it = CostBUSIterator(g_oe, :Int, 20, costs_oe, nothing)

    suite["No OE"] = @benchmarkable foreach(identity, $it)

    it_oe = CostBUSIterator(g_oe, :Int, 20, costs_oe, eval_prog(inputs))

    suite["With OE"] = @benchmarkable foreach(identity, $it_oe)

    return suite
end

function populate!(suite)
    suite["Compositions"] = bench_compositions()
    suite["CostBUSIterator"] = bench_cost_bus()
    return nothing
end

const SUITE = BenchmarkGroup()
populate!(SUITE)

