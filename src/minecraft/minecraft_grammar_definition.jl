using HerbGrammar

struct MinecraftGrammarConfiguration 
    minecraft_grammar::ContextSensitiveGrammar
    angelic_conditions::Dict{UInt16, UInt8}
end

function get_minecraft_grammar_config()
    g = @csgrammar begin
        Program = (state = Init; Blocks; End)
        Init = mc_init(start_pos)
        Blocks = Block | (Block ; Blocks)
        Block = (while true
            Move;
            Bool || break
        end)
        Block = Move
        Block = (if Bool Move end)
        Move = mc_move!(state, Direction, Times, Sprint, Jump)
        Direction = (["forward"]) | (["back"]) | (["left"]) | (["right"]) | (["forward", "left"]) | (["forward", "right"]) | (["back", "left"]) | (["back", "right"])
        Bool = mc_was_good_move(state)
        Bool = mc_has_moved(state)
        Bool = mc_is_done(state)
        Bool = !Bool
        End = mc_end(state)
    end

    # workaround to add right-hand side repeating rules
    rules_to_add = [
        (:Times, 1),
        (:Times, 2),
        (:Times, 3),
        (:Times, 4),
        (:Sprint, true),
        (:Sprint, false),
        (:Jump, true),
        (:Jump, false)
    ]

    for (typ, expr) in rules_to_add
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
    # Update supplemental data structures in bulk
    alltypes = collect(keys(g.bytype))
    g.isterminal = [isterminal(rule, alltypes) for rule ∈ g.rules]
    g.childtypes = [get_childtypes(rule, alltypes) for rule ∈ g.rules]
    g.bychildtypes = [BitVector([g.childtypes[i1] == g.childtypes[i2] for i2 ∈ 1:length(g.rules)]) for i1 ∈ 1:length(g.rules)]
    g.domains = Dict(type => BitArray(r ∈ g.bytype[type] for r ∈ 1:length(g.rules)) for type ∈ keys(g.bytype))

    angelic_conditions = Dict{UInt16, UInt8}(5 => 2, 7 => 1)
    return MinecraftGrammarConfiguration(deepcopy(g), angelic_conditions)
end

"""
    grammar_to_list(grammar::ContextSensitiveGrammar)

Converts a grammar to a list of strings that represent each rule.
"""
function grammar_to_list(grammar::ContextSensitiveGrammar)
    rules = Vector{String}()
    for i in eachindex(grammar.rules)
        type = grammar.types[i]
        rule = grammar.rules[i]
        push!(rules, "$type => $rule")
    end
    return rules
end