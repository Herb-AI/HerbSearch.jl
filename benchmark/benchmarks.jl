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
    grammar = @csgrammar begin
        Int = x
        Int = 0
        Int = Int + Int
    end
    start_symbol = :Int
    max_cost = 10
    rule_costs = [1, 1, 1]
    inputs = [1, 2, 3]

    function ev(p, x)
        p.ind == 1 && return x
        p.ind == 2 && return 0
        return ev(p.children[1], x) + ev(p.children[2], x)
    end

    function program_to_outputs(prog::RuleNode, inputs)
        return ev.((prog,), inputs)
    end
    program_to_outputs(i) = Base.Fix2(program_to_outputs, i)

    it = CostBUSIterator(; grammar, start_symbol, max_cost, rule_costs, program_to_outputs = nothing)

    suite["No OE"] = @benchmarkable foreach(identity, $it)

    it_oe = CostBUSIterator(; grammar, start_symbol, max_cost, rule_costs, program_to_outputs = program_to_outputs(inputs))

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

