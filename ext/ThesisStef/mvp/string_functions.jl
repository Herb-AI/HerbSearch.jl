using MLStyle
# CVC5 functions

## String typed
concat_cvc(str1, str2) = str1 * str2

replace_cvc(mainstr, to_replace, replace_with) = replace(mainstr, to_replace => replace_with)

at_cvc(str, index::Int) = checkbounds(Bool, str, index) ? str[index:index] : nothing

int_to_str_cvc(n::Int) = "$n"

substr_cvc(str, start_index::Int, end_index::Int) = checkbounds(Bool, str, start_index) && checkbounds(Bool, str, end_index) ? str[start_index:end_index] : nothing

# Int typed
len_cvc(str) = length(str)

str_to_int_cvc(str) = tryparse(Int64, str)

function indexof_cvc(str, substring, index::Int)
        n = findfirst(substring, str)
        
        if isnothing(n)
                return -1
        elseif length(n) == 0
                return -1
        else
                return n[1] >= index ? n[1] : -1
        end
end

# Bool typed
prefixof_cvc(prefix, str) = startswith(str, prefix)

suffixof_cvc(suffix, str) = endswith(str, suffix)

contains_cvc(str, contained) = contains(str, contained)

lt_cvc(str1, str2) = cmp(str1, str2) < 0

leq_cvc(str1, str2) = cmp(str1, str2) <= 0

isdigit_cvc(str) = tryparse(Int, str) !== nothing

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
        _interpret_sygus(prog, grammar_tags, args)
end

function _interpret_sygus(prog::AbstractRuleNode, grammar_tags::Dict{Int,Any}, args::Dict{Symbol,Any})
        r = get_rule(prog)
        cs = [_interpret_sygus(c, grammar_tags, args) for c in get_children(prog)]

        if any(==(nothing), cs)
                return nothing
        end



        MLStyle.@match grammar_tags[r] begin
                :concat_cvc     => concat_cvc(cs[1], cs[2])
                :replace_cvc    => replace_cvc(cs[1], cs[2], cs[3])
                :at_cvc         => at_cvc(cs[1], cs[2])
                :int_to_str_cvc => int_to_str_cvc(cs[1])
                :substr_cvc     => substr_cvc(cs[1], cs[2], cs[3])
                :len_cvc        => len_cvc(cs[1])
                :str_to_int_cvc => str_to_int_cvc(cs[1])
                :indexof_cvc    => indexof_cvc(cs[1], cs[2], cs[3])
                :prefixof_cvc   => prefixof_cvc(cs[1], cs[2])
                :suffixof_cvc   => suffixof_cvc(cs[1], cs[2])
                :contains_cvc   => contains_cvc(cs[1], cs[2])
                
                :+              => cs[1] + cs[2]
                :-              => cs[1] - cs[2]
                :and            => cs[1] && cs[2]
                :or             => cs[1] || cs[2]
                :(==)           => cs[1] == cs[2]
                :(!=)           => cs[1] != cs[2]
                :(<)            => cs[1] < cs[2]
                :(<=)           => cs[1] <= cs[2]
                :(>)            => cs[1] > cs[2]
                :(>=)           => cs[1] >= cs[2]
                :!              => !cs[1]

                :IF             => cs[1] ? cs[2] : cs[3]
                
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