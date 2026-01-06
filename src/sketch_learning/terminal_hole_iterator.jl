function collect_uniform_holes(node)
    holes = UniformHole[]
    function visit(n)
        if n isa UniformHole
            push!(holes, n)
        elseif n isa RuleNode
            for c in HerbCore.get_children(n)
                visit(c)
            end
        end
    end
    visit(node)
    return holes
end

function terminal_rules_of_type(grammar, T::Symbol)
    mask = grammar.isterminal .& grammar.domains[T]
    return findall(mask)
end


mutable struct TerminalHoleSolver
    grammar
    sketch::AbstractRuleNode
    holes::Vector{UniformHole}
    terminal_rules::Vector{Vector{Int}}   # per hole
    counters::Vector{Int}
    done::Bool
end

function instantiate_sketch(solver::TerminalHoleSolver)
    hole_to_rule = IdDict{UniformHole, Int}()

    for (i, hole) in enumerate(solver.holes)
        hole_to_rule[hole] =
            solver.terminal_rules[i][solver.counters[i]]
    end

    function rebuild(node)
        if node isa UniformHole
            return RuleNode(hole_to_rule[node], [])
        elseif node isa RuleNode
            return RuleNode(
                get_rule(node),
                map(rebuild, HerbCore.get_children(node))
            )
        else
            error("Unsupported node type: $(typeof(node))")
        end
    end

    return rebuild(solver.sketch)
end


function advance!(solver::TerminalHoleSolver)
    isempty(solver.counters) && (solver.done = true; return)

    for i in length(solver.counters):-1:1
        solver.counters[i] += 1
        if solver.counters[i] <= length(solver.terminal_rules[i])
            return
        else
            solver.counters[i] = 1
        end
    end
    solver.done = true
end


function TerminalHoleSolver(grammar, sketch::AbstractRuleNode)
    holes = collect_uniform_holes(sketch)

    terminal_rules = Vector{Vector{Int}}()
    for h in holes
        rule_idx = findfirst(identity, h.domain)
        rule_idx === nothing && error("UniformHole has empty domain")

        hole_type = grammar.types[rule_idx]
        terms = terminal_rules_of_type(grammar, hole_type)
        isempty(terms) && error("No terminal rules for type $hole_type")

        push!(terminal_rules, terms)
    end

    counters = ones(Int, length(holes))

    return TerminalHoleSolver(
        grammar,
        sketch,
        holes,
        terminal_rules,
        counters,
        false
    )
end


mutable struct TerminalHoleIterator
    solver::TerminalHoleSolver
end


function next_solution!(iter::TerminalHoleIterator)
    solver = iter.solver
    solver.done && return nothing

    prog = instantiate_sketch(solver)
    advance!(solver)
    return prog
end
