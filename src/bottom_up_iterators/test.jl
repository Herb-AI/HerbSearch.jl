using HerbConstraints
using HerbCore
using HerbGrammar
using HerbInterpret
using HerbSearch
using HerbSpecification

import HerbSearch: heuristic_cost

function interp(program::RuleNode)
    r = get_rule(program)
    cs = get_children(program)

    if r == 1
        return 1
    elseif r == 2
        return interp(cs[1]) + interp(cs[2])
    elseif r == 3
        return interp(cs[1]) * interp(cs[2])
    elseif r == 4
        return interp(cs[1]) - interp(cs[2])
    end
end

function heuristic_cost(::BeamBottomUpIterator, program::RuleNode)
    v = interp(program)
    t = -100
    return abs(v - t)
end


grammar = @cfgrammar begin
    Int = 1
    Int = Int + Int
    Int = Int * Int
    Int = Int - Int
end

iterator = BeamBottomUpIterator(grammar, :Int)


for (i, p) in enumerate(iterator)
    v = interp(p)
    c = heuristic_cost(iterator, p)

    println()
    @show p
    @show v
    @show c

    if i == 10
        break
    end
end