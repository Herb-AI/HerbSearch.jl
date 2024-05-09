using HerbGrammar, HerbSpecification, HerbSearch, HerbInterpret
using BenchmarkTools

my_replace(x, y, z) = replace(x, y => z, count=1)

example_grammar = @pcsgrammar begin
    0.188:S = arg
    0.188:S = ""
    0.188:S = "<"
    0.188:S = ">"
    0.188:S = my_replace(S, S, S)
    0.059:S = S * S
end

examples = [
    IOExample(Dict(:arg => "a < 4 and a > 0"), "a  4 and a  0")    # <- e0 with correct space
    IOExample(Dict(:arg => "<open and <close>"), "open and close") # <- e1
]

# benchmarks the guided search iteartor until certain level
function time_iter(; max_level, iterator)
    iter = iterator(example_grammar, :S, examples, SymbolTable(example_grammar))
    next = iterate(iter)
    level = 0
    @time while !isnothing(next) && level <= max_level
        program, state = next
        level = state.level
        next = iterate(iter, state)
    end
end

using Logging
Logging.disable_logging(LogLevel(1000))

# use probability
HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_prob(rule_index, grammar)

max_level = 30
runs = 4
printstyled("Optimized\n"; color=:green)
for _ ∈ 1:runs
    time_iter(max_level=max_level, iterator=GuidedSearchIteratorOptimzed)
end

println("=====================================")
printstyled("Normal version\n", color=:green)

for _ ∈ 1:runs
    time_iter(max_level=max_level, iterator=GuidedSearchIterator)
end