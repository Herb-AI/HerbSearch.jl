
using HerbGrammar, HerbSpecification, HerbSearch

my_replace(x,y,z) = replace(x,y => z, count = 1)

grammar = @pcsgrammar begin 
    0.188 : S = arg
    0.188 : S =  "" 
    0.188 : S =  "<" 
    0.188 : S =  ">"
    0.188 : S = my_replace(S,S,S)
    0.059 : S = S * S
end

examples = [ 
            IOExample(Dict(:arg => "a < 4 and a > 0"), "a  4 and a  0")    # <- e0 with correct space
            # IOExample(Dict(:arg => "a < 4 and a > 0"), "a 4 and a 0")    # <- e0 with incorrect space
            IOExample(Dict(:arg => "<open and <close>"), "open and close") # <- e1
            IOExample(Dict(:arg => "<Change> <string> to <a> number"), "Change string to a number")
        ]

iter = HerbSearch.GuidedSearchIterator(grammar, :S, examples, SymbolTable(grammar))
# @profview program = @time probe(examples, iter, identity, identity, 3600, 10000)
for i in 1:6
    print(iter.grammar.log_probabilities[i])
end
program = @time probe(examples, iter,  3600, 10000)


rulenode2expr(program, grammar)
