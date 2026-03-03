# Defined in SMT-LIB

bvneg_cvc(n::UInt) = -n
bvnot_cvc(n::UInt) = ~n
bvadd_cvc(n1::UInt, n2::UInt) = n1 + n2
bvsub_cvc(n1::UInt, n2::UInt) = n1 - n2
bvxor_cvc(n1::UInt, n2::UInt) = n1 ⊻ n2 #xor
bvand_cvc(n1::UInt, n2::UInt) = n1 & n2
bvor_cvc(n1::UInt, n2::UInt) = n1 | n2
bvshl_cvc(n1::UInt, n2::Int) = n1 << n2
bvlshr_cvc(n1::UInt, n2::Int) = n1 >>> n2
bvashr_cvc(n1::UInt, n2::Int) = n1 >> n2
bvnand_cvc(n1::UInt, n2::UInt) = n1 ⊼ n2 #nand
bvnor_cvc(n1::UInt, n2::UInt) = n1 ⊽ n2 #nor

# CUSTOM functions

ehad_cvc(n::UInt) = bvlshr_cvc(n, 1)
arba_cvc(n::UInt) = bvlshr_cvc(n, 4)
shesh_cvc(n::UInt) = bvlshr_cvc(n, 16)
smol_cvc(n::UInt) = bvshl_cvc(n, 1)
im_cvc(x::UInt, y::UInt, z::UInt) = x == UInt(1) ? y : z
if0_cvc(x::UInt, y::UInt, z::UInt) = x == UInt(0) ? y : z

function get_relevant_tags(grammar::ContextSensitiveGrammar)
        tags = Dict{Int,Any}()
        for (ind, r) in pairs(grammar.rules)
                tags[ind] = if typeof(r) != Expr
                        r
                else
                        @match r.head begin
                                :block => :OpSeq
                                :call => r.args[1]
                                :if => :IF
                        end
                end
        end
        return tags
end

function interpret_sygus(prog::AbstractRuleNode, grammar_tags::Dict{Int,Any}, args::Dict{Symbol,Any})        
    r = get_rule(prog)
    cs = [interpret_sygus(c, grammar_tags, args) for c in get_children(prog)]

    if any(==(nothing), cs)
            return nothing
    end

    MLStyle.@match grammar_tags[r] begin
        :bvneg_cvc => bvneg_cvc(cs[1])
        :bvnot_cvc => bvnot_cvc(cs[1])
        :bvadd_cvc => bvadd_cvc(cs[1], cs[2])
        :bvsub_cvc => bvsub_cvc(cs[1], cs[2])
        :bvxor_cvc => bvxor_cvc(cs[1], cs[2])
        :bvand_cvc => bvand_cvc(cs[1], cs[2])
        :bvor_cvc  => bvor_cvc(cs[1], cs[2])
        :bvshl_cvc => bvshl_cvc(cs[1], cs[2])
        :bvlshr_cvc => bvlshr_cvc(cs[1], cs[2])
        :bvashr_cvc => bvashr_cvc(cs[1], cs[2])
        :bvnand_cvc => bvnand_cvc(cs[1], cs[2])
        :bvnor_cvc  => bvnor_cvc(cs[1], cs[2])

        :ehad_cvc  => bvlshr_cvc(cs[1], 1)
        :arba_cvc  => bvlshr_cvc(cs[1], 4)
        :shesh_cvc => bvlshr_cvc(cs[1], 16)
        :smol_cvc  => bvshl_cvc(cs[1], 1)
        :im_cvc    => cs[1] == UInt(1) ? cs[2] : cs[3]
        :if0_cvc   => cs[1] == UInt(0) ? cs[2] : cs[3]


        :(==)      => cs[1] == cs[2]
        :(!=)      => cs[1] != cs[2]
        :(<)       => cs[1] < cs[2]
        :(<=)      => cs[1] <= cs[2]
        :(>)       => cs[1] > cs[2]
        :(>=)      => cs[1] >= cs[2]
            
        :_arg_1 => args[:_arg_1]
        :_arg_2 => args[:_arg_2]
        :_arg_3 => args[:_arg_3]
        :_arg_4 => args[:_arg_4]
        :_arg_5 => args[:_arg_5]
        :_arg_6 => args[:_arg_6]
        :_arg_out => args[:_arg_out]

        _ => grammar_tags[r]
    end
end