
function generate_properties(;
    grammar,
    property_symbol,
    interpreter,
    max_depth,
    max_size,
)
    properties = []

    for program in BFSIterator(grammar, property_symbol, max_depth = max_depth, max_size = max_size)
        p = freeze_state(program)
        func = y -> interpreter(p, y)
        repr = rulenode2expr(program, grammar)
        push!(properties, (func, repr))
    end

    return properties
end