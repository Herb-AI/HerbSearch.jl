# A minimal, loopback-only HTTP server (stdlib `Sockets` only) that lets the inspector page
# pull the search forward. It serves exactly two things: the page, and JSON deltas.

"""
    InspectServer

The loopback HTTP endpoint of a live [`Inspection`](@ref).

The server binds to `127.0.0.1` only and every route is prefixed with a random token, so
other pages in the browser cannot drive somebody else's search. Requests are handled one at
a time under the inspection's lock; the search itself always stays on its own task.
"""
mutable struct InspectServer
    listener::Sockets.TCPServer
    port::Int
    token::String
    url::String
    task::Union{Task,Nothing}
end

function Base.close(server::InspectServer)
    try
        close(server.listener)
    catch
    end
    return server
end

Base.show(io::IO, s::InspectServer) = print(io, "InspectServer(", s.url, ")")

_random_token() = Random.randstring(['a':'z'; 'A':'Z'; '0':'9'], 16)

"""
    serve!(insp::Inspection; port=0) -> Inspection

Start the local server for `insp` and store it in `insp.server`. Port `0` picks a free port.
"""
function serve!(insp::Inspection; port::Integer=0)
    isnothing(insp.server) || return insp
    listener = Sockets.listen(Sockets.localhost, port)
    actual_port = Int(Sockets.getsockname(listener)[2])
    token = _random_token()
    server = InspectServer(listener, actual_port, token,
        "http://127.0.0.1:$(actual_port)/$(token)/", nothing)
    server.task = @async _accept_loop(insp, server)
    insp.server = server
    return insp
end

function _accept_loop(insp::Inspection, server::InspectServer)
    while isopen(server.listener)
        # NB: `Sockets.accept`, not HerbSearch's own stochastic-search `accept`
        sock = try
            Sockets.accept(server.listener)
        catch err
            # closing the listener is the normal way to stop
            isopen(server.listener) && @warn "the inspector stopped accepting connections" exception = err
            break
        end
        @async _handle_connection(insp, server, sock)
    end
    return nothing
end

function _handle_connection(insp::Inspection, server::InspectServer, sock)
    try
        request = readline(sock)
        parts = split(strip(request))
        length(parts) >= 2 || return
        method, target = parts[1], parts[2]
        while true # skip the headers, we never read a body
            line = readline(sock)
            isempty(strip(line)) && break
        end
        method == "GET" || return _respond(sock, "405 Method Not Allowed", "text/plain", "")

        path, query = _split_target(target)
        prefix = "/" * server.token
        if !(path == prefix || startswith(path, prefix * "/"))
            return _respond(sock, "404 Not Found", "text/plain", "not found")
        end
        route = strip(path[length(prefix)+1:end], '/')

        if route == ""
            _respond(sock, "200 OK", "text/html; charset=utf-8", render_html(insp; live=server))
        elseif route == "pull"
            _respond(sock, "200 OK", "application/json; charset=utf-8", _pull(insp, query))
        else
            _respond(sock, "404 Not Found", "text/plain", "not found")
        end
    catch err
        err isa Base.IOError && return
        @warn "inspector request failed" exception = (err, catch_backtrace())
    finally
        try
            close(sock)
        catch
        end
    end
    return nothing
end

function _respond(sock, status::AbstractString, content_type::AbstractString, body::AbstractString)
    write(sock, "HTTP/1.1 $status\r\n",
        "Content-Type: $content_type\r\n",
        "Content-Length: $(sizeof(body))\r\n",
        "Cache-Control: no-store\r\n",
        "Connection: close\r\n\r\n")
    write(sock, body)
    return nothing
end

function _split_target(target::AbstractString)
    i = findfirst('?', target)
    isnothing(i) && return (target, Dict{String,String}())
    query = Dict{String,String}()
    for pair ∈ split(target[i+1:end], '&')
        isempty(pair) && continue
        j = findfirst('=', pair)
        isnothing(j) ? (query[pair] = "") : (query[pair[1:j-1]] = pair[j+1:end])
    end
    return (target[1:i-1], query)
end

function _query_int(query::AbstractDict, key::AbstractString, default::Int)
    haskey(query, key) || return default
    value = tryparse(Int, query[key])
    return isnothing(value) ? default : value
end

# Advance the search as requested and return everything the client does not have yet.
function _pull(insp::Inspection, query::AbstractDict)
    programs = clamp(_query_int(query, "programs", 0), 0, 10_000)
    events = clamp(_query_int(query, "events", 0), 0, 100_000)
    return lock(insp.lock) do
        advance!(insp; programs=programs, events=events)
        have_events = clamp(_query_int(query, "haveEvents", 0), 0, length(insp.events))
        have_steps = clamp(_query_int(query, "haveSteps", 0), 0, length(insp.steps))
        payload = Dict{String,Any}(
            "events" => Any[_payload(e) for e ∈ insp.events[have_events+1:end]],
            "steps" => Any[_payload(s) for s ∈ insp.steps[have_steps+1:end]],
            "totalEvents" => length(insp.events),
            "totalSteps" => length(insp.steps),
            "open" => length(insp.trace.stack),
            "finished" => insp.finished,
        )
        return to_json(payload)
    end
end
