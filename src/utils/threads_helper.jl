function safe_put!(c, i)
    try
        put!(c, i)
    catch e
        # handle the case that the channel could have been closed in the meantime
        e isa InvalidStateException || rethrow()
    end
end