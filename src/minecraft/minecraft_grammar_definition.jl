using HerbGrammar

struct MinecraftGrammarConfiguration
    minecraft_grammar::ContextSensitiveGrammar
    angelic_conditions::Dict{UInt16,UInt8}
end

function get_minecraft_grammar(recursion_depth::Int=0)
    minecraft_grammar = @csgrammar begin
        Program = (
            state = Init;
            Statement;
            End)
        Init = mc_init(start_pos)
        InnerStatement = (mc_move!(state, Direction, Times, Toggle, Toggle, false))
        InnerStatement = (InnerStatement; InnerStatement)
        InnerStatement = (
            if Bool
                Statement
            end)
        Statement = InnerStatement
        Statement = (Statement; Statement)
        Statement = (
            while true
                InnerStatement
                Bool || break
            end)
        End = mc_end(state)
        Direction = (["forward"]) | (["back"]) | (["left"]) | (["right"]) | (["forward", "left"]) | (["forward", "right"]) | (["back", "left"]) | (["back", "right"])
        Toggle = false | true
        Times = 1 | 2 | 3 | 4
        Bool = is_done(state)
        Bool = !Bool
        End = mc_end(state)
        Bool = mc_was_good_move(state)
        Bool = mc_has_moved(state)
    end
    
    for n in 2:recursion_depth
        expr = Expr(:block)
        for _ in 1:n
            push!(expr.args, :(Statement))
        end
        e = :(Statement = $expr)
        add_rule!(minecraft_grammar, e)
    end
    
    angelic_conditions = Dict{UInt16,UInt8}(5 => 1, 8 => 2)
    return MinecraftGrammarConfiguration(deepcopy(minecraft_grammar), angelic_conditions)
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