using HerbConstraints
using HerbCore
using HerbGrammar
using HerbInterpret
using HerbSearch
using HerbSpecification

# using Profile, ProfileView

# Profile.clear()

function interp(program::AbstractRuleNode)
    if !isnothing(program._val)
        return program._val
    end

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
    end
end

function heuristic_cost(program::AbstractRuleNode, children::Union{Vector{BeamEntry},Nothing})
    v = interp(program)
    t = 100
    return abs(v - t)
end


grammar = @cfgrammar begin
    Int = 1 | 2 | 3
    Int = Int + Int
    Int = Int * Int
    Int = Int - Int
    Int = - Int
end

iterator = BeamIteratorAlt(grammar, :Int,
    beam_size = 30,
    program_to_cost = heuristic_cost,
    max_extension_depth = 3,
    max_extension_size = 5,
    stop_expanding_beam_once_replaced = true,
    interpreter = interp,
    observation_equivalance = true,
)

for (i, entry) in enumerate(iterator)
    p = entry.program
    e = rulenode2expr(p, grammar)
    c = entry.cost
    println()
    @show i
    @show e
    @show p._val
    @show c

    # @show [e.cost for e in iterator.beam.programs]

    if i == 1000
        break
    end
end