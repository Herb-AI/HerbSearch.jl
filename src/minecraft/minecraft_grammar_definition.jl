using HerbGrammar

struct MinecraftGrammarConfiguration 
    minecraft_grammar::ContextSensitiveGrammar
    angelic_conditions::Dict{UInt16, UInt8}
end

function get_minecraft_grammar()
    minecraft_grammar =  @csgrammar begin
        Program = (
            state = Init;
            Statement;
            End)
        Init = mc_init(start_pos)
        InnerStatement = (mc_move!(state, Direction, Times, Toggle, Toggle, false))
        InnerStatement = (InnerStatement ; InnerStatement)
        InnerStatement = (
            if Bool 
                Statement
            end)
        Statement = InnerStatement
        Statement = (Statement ; Statement)
        Statement = (
            while true
                InnerStatement;
                Bool || break
            end)
        End = mc_end(state)
        Direction = (["forward"]) | (["back"]) | (["left"]) | (["right"]) | (["forward", "left"]) | (["forward", "right"]) | (["back", "left"]) | (["back", "right"])
        Toggle = 0 | 1
        Times = 1 | 2 | 3 | 4
        Bool = is_done(state)
        Bool = !Bool
        End = mc_end(state)
        Bool = mc_was_good_move(state)
        Bool = mc_has_moved(state)
    end

    angelic_conditions = Dict{UInt16, UInt8}(5 => 1, 8 => 2)
    return MinecraftGrammarConfiguration(minecraft_grammar, angelic_conditions)
end