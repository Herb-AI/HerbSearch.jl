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
# use size cost because that gives more programs
HerbSearch.calculate_rule_cost(rule_index::Int, grammar::ContextSensitiveGrammar) = HerbSearch.calculate_rule_cost_size(rule_index, grammar)

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

println("Normal version")
bench1 = @benchmarkable time_iter(max_level = 15, iterator = GuidedSearchIterator)
tune!(bench1)
run(bench1)
println("=====================================")

printstyled("Optimized"; color=:green)
bench2 = @benchmarkable time_iter(max_level = 15, iterator = GuidedSearchIteratorOptimzed)
tune!(bench2)
run(bench2)