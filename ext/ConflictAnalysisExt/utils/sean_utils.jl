function evaluate_expr_naive(ex::Expr, symbol_values::Dict{Symbol, Any})
    assignments = Expr(:block, [Expr(:(=), k, v) for (k, v) in pairs(symbol_values)]...)
    full_expr = Expr(:let, assignments, ex)
    return eval(full_expr)
end

function extract_sec(
    semantic::Expr,
    grammar::AbstractGrammar,
    return_type_node::Symbol,
    child_types::Vector{Symbol}
)
    sec_class = Vector{Int}()

    for (rule_index, spec) in enumerate(grammar.specification)
        if return_type(grammar, rule_index) != return_type_node || grammar.childtypes[rule_index] != child_types
            continue
        end

        if semantic in spec
            push!(sec_class, rule_index)
        end
    end

    return sec_class
end