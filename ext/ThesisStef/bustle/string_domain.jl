string_grammar = @HerbGrammar.cfgrammar begin
    String = concat(String, String)
    String = left(String, Int)
    String = right(String, Int)
    String = substr(String, Int, Int)
    String = replace(String, Int, Int, String)
    String = trim(String)
    String = repeat(String, Int)
    String = substitute(String, String, String)
    String = substitute_2(String, String, String, Int)
    String = totext(Int)
    String = lowercase(String)
    String = uppercase(String)
    String = propercase(String)
    String = "" | " " | "," | "." | "!" | "?" | "(" | ")" | "[" | "]" | "<" | ">" | "{" | "}" | "-" | "+" | "_" | "/" | "\$" | "#" | ":" | ";" | "@" | "%" | "0"

    Int = Int + Int
    Int = Int - Int
    Int = find(String, String)
    Int = find_2(String, String, Int)
    Int = len(String)
    Int = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30

    String = _arg_1
end


concat(s1::String, s2::String) = s1 * s2

function left(s::String, i::Int)
    i ≤ 0 || isempty(s) && return ""
    return String(collect(Iterators.take(s, i)))
end

function right(s::String, i::Int)
    if i ≤ 0 || isempty(s)
        return ""
    end
    # take last i characters, safely, with Unicode support
    chars = collect(Iterators.take(reverse(s), i))
    return String(reverse(chars))
end

function substr(s::String, i1::Int, i2::Int)
    # empty string or invalid range → return ""
    isempty(s) && return ""
    i2 < i1 && return ""

    n = length(s)

    # clamp to valid character indices
    i1 = max(i1, 1)
    i2 = min(i2, n)

    # after clamping, invalid?
    i1 > i2 && return ""

    # drop first (i1-1) chars, then take (i2-i1+1)
    it = Iterators.take(Iterators.drop(s, i1 - 1), i2 - i1 + 1)
    return String(collect(it))
end

replace_1(s1::String, i1::Int, i2::Int, s2::String) = s1[1:i1-1] * s2 * s1[i2+1:end]

trim(s::String) = String(strip(s))

repeat(s::String, i::Int) = Base.repeat(s, i)

substitute(s1::String, s2::String, s3::String) = Base.replace(s1, s2 => s3)

substitute_2(s1::String, s2::String, s3::String, i::Int) = Base.replace(s1, s2 => s3, i)

totext(i::Int) = "$i"

lowercase(s::String) = Base.lowercase(s)

uppercase(s::String) = Base.uppercase(s)

propercase(s::String) = isempty(s) ? "" : Base.uppercase(first(s)) * Base.lowercase(s[2:end])

function find(s1::String, s2::String)
    res = findfirst(s2, s1)

    if isnothing(res)
        return -1
    end

    return first(res)
end

function find_2(s1::String, s2::String, i::Int)
    res = (findnext(s2, s1, i))

    if isnothing(res)
        return -1
    end

    return first(res)
end

len(s::String) = length(s)


function interpret_string(prog::AbstractRuleNode, grammar_tags::Dict{Int,Any}, input::String)::Union{String, Int}
    r = get_rule(prog)
    c = get_children(prog)

    # @show prog
    # @show r
    # @show grammar_tags

    MLStyle.@match grammar_tags[r] begin
            :trim           => trim(interpret_string(c[1], grammar_tags, input))
            :totext         => totext(interpret_string(c[1], grammar_tags, input))
            :lowercase      => lowercase(interpret_string(c[1], grammar_tags, input))
            :uppercase      => uppercase(interpret_string(c[1], grammar_tags, input))
            :propercase     => propercase(interpret_string(c[1], grammar_tags, input))
            :len            => len(interpret_string(c[1], grammar_tags, input))

            :concat         => concat(interpret_string(c[1], grammar_tags, input), interpret_string(c[2], grammar_tags, input))
            :left           => left(interpret_string(c[1], grammar_tags, input), interpret_string(c[2], grammar_tags, input))
            :right          => right(interpret_string(c[1], grammar_tags, input), interpret_string(c[2], grammar_tags, input))
            :repeat         => repeat(interpret_string(c[1], grammar_tags, input), interpret_string(c[2], grammar_tags, input))
            :find           => find(interpret_string(c[1], grammar_tags, input), interpret_string(c[2], grammar_tags, input))

            :substr         => substr(interpret_string(c[1], grammar_tags, input), interpret_string(c[2], grammar_tags, input), interpret_string(c[3], grammar_tags, input))
            :substitute     => substitute(interpret_string(c[1], grammar_tags, input), interpret_string(c[2], grammar_tags, input), interpret_string(c[3], grammar_tags, input))
            :find_2         => find_2(interpret_string(c[1], grammar_tags, input), interpret_string(c[2], grammar_tags, input), interpret_string(c[3], grammar_tags, input))

            :replace        => replace_1(interpret_string(c[1], grammar_tags, input), interpret_string(c[2], grammar_tags, input), interpret_string(c[3], grammar_tags, input), interpret_string(c[4], grammar_tags, input))
            :substitute_2   => substitute_2(interpret_string(c[1], grammar_tags, input), interpret_string(c[2], grammar_tags, input), interpret_string(c[3], grammar_tags, input), interpret_string(c[4], grammar_tags, input))

            :+              => interpret_string(c[1], grammar_tags, input) + interpret_string(c[2], grammar_tags, input)
            :-              => interpret_string(c[1], grammar_tags, input) - interpret_string(c[2], grammar_tags, input)

            :_arg_1         => input

            _               => grammar_tags[r]
    end
end

function get_relevant_tags(grammar::ContextSensitiveGrammar)
    tags = []

    for (ind, r) in pairs(grammar.rules)
            value = if typeof(r) != Expr
                    r
            else
                    @match r.head begin
                            :block => :OpSeq
                            :call => r.args[1]
                            :if => :IF
                    end
            end

            push!(tags, (ind, value))
    end

    return Dict(tags)
end