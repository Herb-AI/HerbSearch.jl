using BenchmarkTools: @benchmarkable, BenchmarkGroup
using HerbSearch: StableNode, CostBUSIterator, compositions
using HerbGrammar: @csgrammar
using HerbCore: RuleNode, get_rule, get_children

function bench_compositions()
    suite = BenchmarkGroup(["bottom-up"])

    params = (n, k) = (25, 10)
    c = compositions(n, k)
    suite[params] = @benchmarkable foreach(identity, $c)

    return suite
end

function ev(p::StableNode, x)
    get_rule(p) == 1 && return x
    get_rule(p) == 2 && return 0

    return ev(get_children(p)[1], x) + ev(get_children(p)[2], x)
end

function program_to_outputs(prog, inputs)
    return ev.((prog,), inputs)
end
program_to_outputs(i) = Base.Fix2(program_to_outputs, i)

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

    it = CostBUSIterator(; grammar, start_symbol, max_cost, rule_costs, program_to_outputs = nothing, node_type=StableNode)

    suite["No OE"] = @benchmarkable foreach(identity, $it)

    it_oe = CostBUSIterator(; grammar, start_symbol, max_cost, rule_costs, program_to_outputs = program_to_outputs(inputs), node_type=StableNode)

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

