using MLStyle
# CVC5 functions

## String typed
concat_cvc(str1::String, str2::String) = str1 * str2

replace_cvc(mainstr::String, to_replace::String, replace_with::String) = replace(mainstr, to_replace => replace_with)

at_cvc(str::String, index::Int) = string(str[index])

int_to_str_cvc(n::Int) = "$n"

substr_cvc(str::String, start_index::Int, end_index::Int) = str[start_index:end_index]

# Int typed
len_cvc(str::String) = length(str)

str_to_int_cvc(str::String) = parse(Int64, str)

indexof_cvc(str::String, substring::String, index::Int) = (n = findfirst(substring, str); n == nothing ? -1 : (n[1] >= index ? n[1] : -1))

# Bool typed
prefixof_cvc(prefix::String, str::String) = startswith(str, prefix)

suffixof_cvc(suffix::String, str::String) = endswith(str, suffix)

contains_cvc(str::String, contained::String) = contains(str, contained)

lt_cvc(str1::String, str2::String) = cmp(str1, str2) < 0

leq_cvc(str1::String, str2::String) = cmp(str1, str2) <= 0

isdigit_cvc(str::String) = tryparse(Int, str) !== nothing

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

function interpret_sygus(prog::AbstractRuleNode, grammar_tags::Dict{Int,Any}, args::Dict{Symbol,Any})
        try
                _interpret_sygus(prog, grammar_tags, args)
        catch e
                if e isa BoundsError || e isa ArgumentError || e isa OverflowError
                        return nothing
                end

                rethrow(e)
        end
end

function _interpret_sygus(prog::AbstractRuleNode, grammar_tags::Dict{Int,Any}, args::Dict{Symbol,Any})
        r = get_rule(prog)
        c = get_children(prog)

        MLStyle.@match grammar_tags[r] begin
                :concat_cvc     => concat_cvc(_interpret_sygus(c[1], grammar_tags, args), _interpret_sygus(c[2], grammar_tags, args))
                :replace_cvc    => replace_cvc(_interpret_sygus(c[1], grammar_tags, args), _interpret_sygus(c[2], grammar_tags, args), _interpret_sygus(c[3], grammar_tags, args))
                :at_cvc         => at_cvc(_interpret_sygus(c[1], grammar_tags, args), _interpret_sygus(c[2], grammar_tags, args))
                :int_to_str_cvc => int_to_str_cvc(_interpret_sygus(c[1], grammar_tags, args))
                :substr_cvc     => substr_cvc(_interpret_sygus(c[1], grammar_tags, args), _interpret_sygus(c[2], grammar_tags, args), _interpret_sygus(c[3], grammar_tags, args))
                :len_cvc        => len_cvc(_interpret_sygus(c[1], grammar_tags, args))
                :str_to_int_cvc => str_to_int_cvc(_interpret_sygus(c[1], grammar_tags, args))
                :indexof_cvc    => indexof_cvc(_interpret_sygus(c[1], grammar_tags, args), _interpret_sygus(c[2], grammar_tags, args), _interpret_sygus(c[3], grammar_tags, args))
                :prefixof_cvc   => prefixof_cvc(_interpret_sygus(c[1], grammar_tags, args), _interpret_sygus(c[2], grammar_tags, args))
                :suffixof_cvc   => suffixof_cvc(_interpret_sygus(c[1], grammar_tags, args), _interpret_sygus(c[2], grammar_tags, args))
                :contains_cvc   => contains_cvc(_interpret_sygus(c[1], grammar_tags, args), _interpret_sygus(c[2], grammar_tags, args))
                
                :+              => _interpret_sygus(c[1], grammar_tags, args) + _interpret_sygus(c[2], grammar_tags, args)
                :-              => _interpret_sygus(c[1], grammar_tags, args) - _interpret_sygus(c[2], grammar_tags, args)
                :and           => _interpret_sygus(c[1], grammar_tags, args) && _interpret_sygus(c[2], grammar_tags, args)
                :or           => _interpret_sygus(c[1], grammar_tags, args) || _interpret_sygus(c[2], grammar_tags, args)
                :(==)           => _interpret_sygus(c[1], grammar_tags, args) == _interpret_sygus(c[2], grammar_tags, args)
                :(!=)           => _interpret_sygus(c[1], grammar_tags, args) != _interpret_sygus(c[2], grammar_tags, args)
                :(<)           => _interpret_sygus(c[1], grammar_tags, args) < _interpret_sygus(c[2], grammar_tags, args)
                :(>)           => _interpret_sygus(c[1], grammar_tags, args) > _interpret_sygus(c[2], grammar_tags, args)
                :!           => !_interpret_sygus(c[1], grammar_tags, args)

                :IF             => _interpret_sygus(c[1], grammar_tags, args) ? _interpret_sygus(c[2], grammar_tags, args) : _interpret_sygus(c[3], grammar_tags, args)
                
                :_arg_1 => args[:_arg_1]
                :_arg_2 => args[:_arg_2]
                :_arg_3 => args[:_arg_3]
                :_arg_4 => args[:_arg_4]
                :_arg_5 => args[:_arg_5]
                :_arg_6 => args[:_arg_6]
                :_arg_out => args[:_arg_out]

                _   => grammar_tags[r]
        end
end