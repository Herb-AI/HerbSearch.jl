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


function replace_symbol(ex, target::Symbol, value)
    if ex === target
        return value
    elseif ex isa Expr
        return Expr(ex.head, map(arg -> replace_symbol(arg, target, value), ex.args)...)
    else
        return ex
    end
end

function interp_sygus_bv(prog::AbstractRuleNode, grammar::AbstractGrammar, args::Dict)
    expr = rulenode2expr(prog, grammar)

    for (sym, val) in args
        expr = replace_symbol(expr, sym, val)
    end

    v = eval(expr)

    return v
end


"""
Gets relevant symbol to easily match grammar rules to operations in `interpret` function
"""
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

function interpret_sygus(prog::AbstractRuleNode, grammar_tags::Dict{Int,Any})
        r = get_rule(prog)
        c = get_children(prog)

        MLStyle.@match grammar_tags[r] begin
                :bvneg_cvc => bvneg_cvc(interpret_sygus(c[1], grammar_tags))
                :bvnot_cvc => bvnot_cvc(interpret_sygus(c[1], grammar_tags))
                :ehad_cvc => ehad_cvc(interpret_sygus(c[1], grammar_tags))
                :arba_cvc => arba_cvc(interpret_sygus(c[1], grammar_tags))
                :shesh_cvc => shesh_cvc(interpret_sygus(c[1], grammar_tags))
                :smol_cvc => smol_cvc(interpret_sygus(c[1], grammar_tags))
                

                :bvadd_cvc     => bvadd_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :bvsub_cvc     => bvsub_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :bvxor_cvc     => bvxor_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :bvand_cvc     => bvand_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :bvor_cvc     => bvor_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :bvshl_cvc     => bvshl_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :bvlshr_cvc     => bvlshr_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :bvashr_cvc     => bvashr_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :bvnand_cvc     => bvnand_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :bvnor_cvc     => bvnor_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :concat_cvc     => concat_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :concat_cvc     => concat_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))
                :concat_cvc     => concat_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags))


                :im_cvc    => im_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags), interpret_sygus(c[3], grammar_tags))
                :if0_cvc    => if0_cvc(interpret_sygus(c[1], grammar_tags), interpret_sygus(c[2], grammar_tags), interpret_sygus(c[3], grammar_tags))
                

                :(==)           => interpret_sygus(c[1], grammar_tags) == interpret_sygus(c[2], grammar_tags)
                :(!=)           => interpret_sygus(c[1], grammar_tags) != interpret_sygus(c[2], grammar_tags)
                :(<)           => interpret_sygus(c[1], grammar_tags) < interpret_sygus(c[2], grammar_tags)
                :(>)           => interpret_sygus(c[1], grammar_tags) > interpret_sygus(c[2], grammar_tags)

                _ => grammar_tags[r]
        end
end

function interpret_sygus(prog::AbstractRuleNode, grammar::AbstractGrammar, args::Dict)
        tags = get_relevant_tags(grammar)

        for (tag, symbol) in tags
                if haskey(args, symbol)
                        tags[tag] = args[symbol]
                end
        end

        try
                return interpret_sygus(prog, tags)
        catch e
                if e isa BoundsError || e isa ArgumentError || e isa OverflowError
                        expr = rulenode2expr(prog, grammar)
                        return nothing
                else
                        rethrow(e)
                end
        end
end

function interpret_sygus(prog::AbstractRuleNode, grammar::AbstractGrammar, problem::Problem)
        examples = problem.spec
        results = []

        for example in examples
                amount_of_args = length(example.in)
                args = Vector{Any}(undef, amount_of_args)

                for (arg, value) in example.in
                        m = match(r"_arg_(\d+)", "$arg")

                        if !isnothing(m)
                                arg_index = parse(Int, m.captures[1])
                                args[arg_index] = value
                        end
                end

                result = interpret_sygus(prog, grammar, args)

                if isnothing(result)
                        return nothing
                end
                
                push!(results, result)
        end
                
        return results
end
