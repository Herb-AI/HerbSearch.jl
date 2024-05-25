function buildProgrammingProblemGrammar(
    input_parameters::AbstractVector{Tuple{Symbol,Symbol}},
    return_type::Symbol,
    intermediate_variables_count::Int=0
)::ContextSensitiveGrammar
    base_grammar = deepcopy(@cfgrammar begin

        Program = (VariableDefintion; Statement; Return) | (Statement; Return) | Return
        VariableDefintion = ListVariable = List

        Statement = (Statement; Statement)
        Statement = (
            i = 0;
            while i < Num
                InnerStatement
                i = i + 1
            end)
        Statement = (
            if Bool
                Statement
            end
        )
        Statement = push!(ListVariable, Num)

        InnerNum = Num | i | (InnerNum + InnerNum)
        InnerStatement = push!(ListVariable, InnerNum)

        Num = |(0:9) | (Num + Num) | (Num - Num)
        Num = getindex(ListVariable, Num)

        Bool = true | false

        List = [] | ListVariable

        ListVariable = list
    end)

    # add return type constraint
    add_rule!(base_grammar, :(Return = return $return_type))

    # add input parameters constraints
    for input_parameter in input_parameters
        add_rule!(base_grammar, :($(input_parameter[2]) = $(input_parameter[1])))
    end

    # what about order constrains for while loops?
    # what about order constrains for variables

    base_grammar
end

function print_grammar(g::AbstractGrammar)
    for i in eachindex(g.rules)
        println(g.log_probabilities[i], "  ", i, ": ", g.types[i], " = ", g.rules[i])
    end
end

"""
    add_fragments_prob!(grammar::AbstractGrammar, fragments_chance::Float64)

Adds the probability of using a fragment rule to the grammar rules. For a fragment rule to be found it should be named `Fragment_<symbol>`.
It should be a terminal rule and have the same type as the symbol it is a fragment of. There should be at most one fragment rule for each symbol.
        
# Arguments
- `grammar`: The grammar rules of the program. Updates its probabilities directly.
- `fragments_chance`: The probability of using a fragment rule.
"""
function add_fragments_prob!(grammar::AbstractGrammar, fragments_chance::Float16, fragment_base_rules_offset::Int16, fragment_rules_offset::Int16)
    if isnothing(grammar.log_probabilities)
        grammar.log_probabilities = fill(Float16(1), length(grammar.rules))
    else
        resize!(grammar.log_probabilities, length(grammar.rules))
    end

    for i in fragment_base_rules_offset+1:fragment_rules_offset
        if isterminal(grammar, i)
            if grammar.log_probabilities[i] != Float16(0)
                grammar.log_probabilities[i] = Float16(0)
                others_prob = Float16(1) / (length(grammar.bytype[grammar.types[i]]) - 1)
                for j in grammar.bytype[return_type(grammar, i)]
                    if j != i
                        grammar.log_probabilities[j] = others_prob
                    end
                end
            end
        else
            if grammar.log_probabilities[i] != fragments_chance
                grammar.log_probabilities[i] = fragments_chance
                others_prob = Float16(1 - fragments_chance) / (length(grammar.bytype[grammar.types[i]]) - 1)
                for j in grammar.bytype[return_type(grammar, i)]
                    if j != i
                        grammar.log_probabilities[j] = others_prob
                    end
                end
            end

            fragments_prob = Float16(1) / length(grammar.bytype[grammar.rules[i]])
            for j in grammar.bytype[grammar.rules[i]]
                grammar.log_probabilities[j] = fragments_prob
            end
        end
    end
end

function add_rules!(g::AbstractGrammar, fragments::AbstractVector{RuleNode})
    for fragment in fragments
        typ = Symbol("Fragment_", return_type(g, fragment))
        expr = rulenode2expr(fragment, g)
        rvec = Any[]
        parse_rule!(rvec, expr)
        for r ∈ rvec
            if !any(r === rule && typ === return_type(g, i) for (i, rule) ∈ enumerate(g.rules))
                push!(g.rules, r)
                push!(g.iseval, iseval(expr))
                push!(g.types, typ)
                g.bytype[typ] = push!(get(g.bytype, typ, Int[]), length(g.rules))
            end
        end
    end
    alltypes = collect(keys(g.bytype))
    g.isterminal = [isterminal(rule, alltypes) for rule ∈ g.rules]
    g.childtypes = [get_childtypes(rule, alltypes) for rule ∈ g.rules]
    g.bychildtypes = [BitVector([g.childtypes[i1] == g.childtypes[i2] for i2 ∈ 1:length(g.rules)]) for i1 ∈ 1:length(g.rules)]
    g.domains = Dict(type => BitArray(r ∈ g.bytype[type] for r ∈ 1:length(g.rules)) for type ∈ keys(g.bytype))
end