# A tiny JSON writer, so that the inspector does not add a dependency to HerbSearch.
# It only has to handle the payload built in `html.jl`.

_json(io::IO, ::Nothing) = print(io, "null")
_json(io::IO, x::Bool) = print(io, x ? "true" : "false")
_json(io::IO, x::Integer) = print(io, x)
_json(io::IO, x::Symbol) = _json(io, String(x))

function _json(io::IO, x::AbstractFloat)
    print(io, isfinite(x) ? string(x) : "null")
end

function _json(io::IO, s::AbstractString)
    print(io, '"')
    for c ∈ s
        if c == '"'
            print(io, "\\\"")
        elseif c == '\\'
            print(io, "\\\\")
        elseif c == '\n'
            print(io, "\\n")
        elseif c == '\r'
            print(io, "\\r")
        elseif c == '\t'
            print(io, "\\t")
        elseif c == '<'
            print(io, "\\u003c") # keeps the payload safe inside a <script> tag
        elseif c < ' '
            print(io, "\\u", lpad(string(UInt16(c), base=16), 4, '0'))
        else
            print(io, c)
        end
    end
    print(io, '"')
end

function _json(io::IO, v::AbstractVector)
    print(io, '[')
    for (i, x) ∈ enumerate(v)
        i > 1 && print(io, ',')
        _json(io, x)
    end
    print(io, ']')
end

function _json(io::IO, d::AbstractDict)
    print(io, '{')
    first = true
    for (k, v) ∈ d
        first || print(io, ',')
        first = false
        _json(io, string(k))
        print(io, ':')
        _json(io, v)
    end
    print(io, '}')
end

_json(io::IO, x) = _json(io, string(x))

function to_json(x)::String
    io = IOBuffer()
    _json(io, x)
    return String(take!(io))
end
