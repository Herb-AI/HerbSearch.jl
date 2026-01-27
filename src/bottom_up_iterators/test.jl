using HerbConstraints
using HerbCore
using HerbGrammar
using HerbInterpret
using HerbSearch
using HerbSpecification

function interp(program::AbstractRuleNode)
    r = get_rule(program)
    cs = get_children(program)

    if r <= 3
        return r
    elseif r == 4
        return interp(cs[1]) + interp(cs[2])
    elseif r == 5
        return interp(cs[1]) * interp(cs[2])
    elseif r == 6
        return interp(cs[1]) - interp(cs[2])
    elseif r == 7
        return - interp(cs[1])
    elseif r == 8
        return interp(cs[1]) ^ interp(cs[2])
    end
end

function heuristic_cost(program::AbstractRuleNode)
    v = interp(program)
    t = -100
    return abs(v - t)
end


grammar = @cfgrammar begin
    Int = 1 | 2 | 3
    Int = Int + Int
    Int = Int * Int
    Int = Int - Int
    Int = - Int
end

iterator = BeamIterator(grammar, :Int,
    beam_size = 3,
    program_to_cost = heuristic_cost,
)

for (i, p) in enumerate(iterator)
    @show p

    if i == 60
        break
    end
end

# println("\n\n\n")
# @show get_bank(iterator)
# println("\n\n\n")

# for (i, p) in enumerate(iterator)
#     v = interp(p)
#     c = heuristic_cost(p)
#     p = rulenode2expr(p, grammar)

#     println()
#     # @show get_bank(iterator)
#     @show i
#     @show p
#     @show v
#     @show c
#     println()

#     if i == 30
#         break
#     end
# end