struct ExprIdBank
    expr2eid::Dict{Any, String}
    eid2expr::Dict{String, Any}
    next_id::Base.RefValue{Int}
end

struct SpecModel
    bank::ExprIdBank
    cons_id_map::Dict{String, Tuple{Int, Tuple{String, String, String}}}
    assigns::Set{String}
end

const EMC_ENTAILS = Dict(
        "<"  => Set(["<"]),
        "<=" => Set(["<", "==", "<="]),
        "==" => Set(["=="]),
        "!=" => Set(["!="]),
        ">"  => Set([">"]),
        ">=" => Set([">", "==", ">="])
)

function infer_spec(
    root::AbstractRuleNode,
    grammar::AbstractGrammar,
    example::IOExample
)
    bank = ExprIdBank(Dict{Any, String}(), Dict{String, Any}(), Ref(1))
    cons_id_map = Dict{String, Tuple{Int, Tuple{String, String, String}}}()
    assigns = Set{String}()

    node_queue = Queue{AbstractRuleNode}()
    enqueue!(node_queue, root)

    while !isempty(node_queue)
        curr_node = dequeue!(node_queue)

        spec = grammar.specification[get_rule(curr_node)]
        node_index = get_index(get_path(root, curr_node), max_arity(grammar))
        child_indices = Int[]

        for (i, child) in enumerate(get_children(curr_node))
            child_index = get_index(get_path(root, child), max_arity(grammar))

            enqueue!(node_queue, child)
            push!(child_indices, child_index)

            if isempty(get_children(child)) && haskey(example.in, rulenode2expr(child, grammar))
                smt_assigns = compile_symbol_assignments(spec, Symbol("x$i"), child_index, example.in[rulenode2expr(child, grammar)], bank)
                union!(assigns, smt_assigns)
            end
        end

        smt_cons_list = parse_node_semantics(spec, node_index, child_indices, bank)
        for (i, smt_cons) in enumerate(smt_cons_list)
            cons_id_map["C_$(node_index)_$i"] = (node_index, smt_cons)
        end
    end

    output = extract_output(root, grammar, example.out, bank)

    if output !== nothing
        union!(assigns, output)
    end

    return SpecModel(bank, cons_id_map, assigns)
end

function smt_solve(
    model::SpecModel,
    interactive_solver::InteractiveSolver,
)
    smt_cmd = string(
        smt_vars(model.bank),
        smt_translate_cons(model.cons_id_map),
        smt_assigns(model.assigns),
        "(check-sat)"
    )

    sat_response = send_command(interactive_solver, smt_cmd, is_done=is_sat_or_unsat)

    if strip(sat_response) == "sat"
        send_command(interactive_solver, "(reset-assertions)", dont_wait=true)
        return nothing
    end

    core = send_command(interactive_solver, "(get-unsat-core)", is_done=nested_parens_match)

    send_command(interactive_solver, "(reset-assertions)", dont_wait=true)
    return core
end

function core_to_constraints(
    core::Vector{String}, 
    cons_id_map::Dict{String, Tuple{Int, Tuple{String, String, String}}}
)
    constraint_node_map = Dict{Int, Vector{Tuple{String, String, String}}}()

    for id in core
        node_idx, cons = cons_id_map[id]
        push!(get!(constraint_node_map, node_idx, Vector{Tuple{String, String, String}}()), cons)
    end

    return constraint_node_map
end

function constraints_to_semantics(
    constraint_node_map::Dict{Int, Vector{Tuple{String, String, String}}},
    root::AbstractRuleNode,
    grammar::AbstractGrammar,
    bank::ExprIdBank
)
    arity = max_arity(grammar)
    semantic_node_map = Dict{Int, Vector{Tuple{Any, String, Any}}}()
    node_queue = Queue{AbstractRuleNode}()
    enqueue!(node_queue, root)

    while !isempty(node_queue)
        curr_node = dequeue!(node_queue)
        node_index = get_index(get_path(root, curr_node), arity)
        mapping = Dict{Symbol, Symbol}(Symbol("v$node_index") => :y)

        for (i, child) in enumerate(get_children(curr_node))
            enqueue!(node_queue, child)
            child_index = get_index(get_path(root, child), arity)
            mapping[Symbol("v$child_index")] = Symbol("x$i")
        end

        if haskey(constraint_node_map, node_index)
            for cons in constraint_node_map[node_index]
                lhs_eid, op, rhs_eid = cons
                lhs_expr = replace_placeholders(bank.eid2expr[lhs_eid], mapping)
                rhs_expr = replace_placeholders(bank.eid2expr[rhs_eid], mapping)
                semantic_node_map[node_index] = push!(get!(semantic_node_map, node_index, Vector{Tuple{Any, String, Any}}()), (lhs_expr, op, rhs_expr))
            end
        end
    end

    return semantic_node_map
end

function extract_emc_class(
    muc::Vector{Tuple{Any, String, Any}},
    grammar::AbstractGrammar,
    return_type_node::Symbol,
    child_types::Vector{Symbol}
)
    emc_class = Set{Int}()
    for muc_semantic in muc
        lhs_muc, op_muc, rhs_muc = muc_semantic

        acceptable_ops = get(EMC_ENTAILS, op_muc, Set{String}())
        if isempty(acceptable_ops)
            @warn "Invalid op, not found in EMC set: $op_muc"
            return nothing
        end

        for (rule_index, spec) in enumerate(grammar.specification)
            if return_type(grammar, rule_index) != return_type_node || grammar.childtypes[rule_index] != child_types 
                continue
            end

            for expr in spec
                parsed_rule = parse_semantic(expr)
                if parsed_rule === nothing
                    @warn "Failed to parse grammar constraint: $parsed_rule"
                    continue
                end
                lhs_r, op_r, rhs_r = parsed_rule

                if lhs_r == lhs_muc && rhs_r == rhs_muc && op_r in acceptable_ops
                    push!(emc_class, rule_index)
                    break
                end
            end
        end
    end

    return collect(emc_class)
end

function extract_output(
    root::AbstractRuleNode,
    grammar::AbstractGrammar,
    val::Any,
    bank::ExprIdBank
)
    node = root
    while isempty(grammar.specification[get_rule(node)])
        if length(get_children(node)) != 1
            return nothing
        end
        node = get_children(node)[1]
    end

    spec = grammar.specification[get_rule(node)]
    node_index = get_index(get_path(root, node), max_arity(grammar))

    return compile_symbol_assignments(spec, :y, node_index, val, bank)
end

function compile_symbol_assignments(
    spec::Vector{Expr},
    sym::Symbol,
    index::Int,
    value::Any,
    bank::ExprIdBank
)
    assigns = String[]
    mapping = Dict{Symbol, Symbol}(sym => Symbol("v$index"))

    for expr in spec
        lhs, _op, rhs = parse_semantic(expr)

        for side in (lhs, rhs)
            val = eval_semantic_side(side, Dict{Symbol, Any}(sym => value))

            if val === nothing
                continue
            end

            side_v = replace_placeholders(side, mapping)

            eid = expr_to_id!(bank, side_v)
            push!(assigns, "(assert (= $eid $val))")
        end
    end

    return assigns
end

function parse_node_semantics(
    spec::Vector{Expr},
    node_index::Int,
    child_indices::Vector{Int},
    bank::ExprIdBank
)
    mapping = Dict{Symbol, Symbol}(:y => Symbol("v$node_index"))
    for (i, cidx) in enumerate(child_indices)
        mapping[Symbol("x$i")] = Symbol("v$cidx")
    end

    smt_cons = Tuple{String, String, String}[]

    for ex in spec
        lhs, op, rhs = parse_semantic(ex)

        lhs_v = replace_placeholders(lhs, mapping)
        rhs_v = replace_placeholders(rhs, mapping)

        lhs_e = expr_to_id!(bank, lhs_v)
        rhs_e = expr_to_id!(bank, rhs_v)

        push!(smt_cons, (lhs_e, op, rhs_e))
    end

    return smt_cons
end

function smt_vars(bank::ExprIdBank)
    return join(["(declare-fun $eid () Int)" for eid in keys(bank.eid2expr)], "\r\n") * "\r\n"
end

function smt_assigns(assigns::Set{String})
    return join(collect(assigns), "\r\n") * "\r\n"
end

function smt_translate_cons(cons_id_map::Dict{String, Tuple{Int, Tuple{String, String, String}}})
    lines = String[]
    for (smt_id, (_, (lhs_e, op, rhs_e))) in cons_id_map
        op2 = op == "==" ? "=" : op
        push!(lines, "(assert (! ($op2 $lhs_e $rhs_e) :named $(smt_id)))")
    end

    return join(lines, "\r\n") * "\r\n"
end

function get_index(path::Vector{Int}, max_arity)
    index = 0
    for p in path
        index = index * max_arity + p
    end
    return index
end

function get_typed_terminals_list(
    grammar::AbstractGrammar,
    terminal_rule::Any
)
    terminals = Int[]
    for (index, terminal) ∈ enumerate(grammar.isterminal)
        if terminal && return_type(grammar, index) == return_type(grammar, terminal_rule) && !occursin("arg", string(grammar.rules[index]))
            push!(terminals, index)
        end
    end
    return terminals
end

function expr_to_id!(
    bank::ExprIdBank,
    x::Any
)
    if haskey(bank.expr2eid, x)
        return bank.expr2eid[x]
    else
        eid = "e$(bank.next_id[])"
        bank.next_id[] += 1
        bank.expr2eid[x] = eid
        bank.eid2expr[eid] = x
        return eid
    end
end

function parse_semantic(ex::Expr)
    @assert ex.head == :call "Constraint must be a call like :(lhs <= rhs), got: $ex"
    @assert length(ex.args) == 3 "Binary constraint expected, got: $ex"
    op = ex.args[1]
    lhs = ex.args[2]
    rhs = ex.args[3]
    return lhs, String(op), rhs
end

function replace_placeholders(
    x::Any, 
    mapping::Dict{Symbol, Symbol}
)
    if x isa Symbol
        return get(mapping, x, x)
    elseif x isa Expr
        return Expr(x.head, (replace_placeholders(a, mapping) for a in x.args)...)
    else
        return x
    end
end

function parse_core_ids(core::String)
    return [String(m.match) for m in eachmatch(r"C_\d+_\d+", core)]
end

function _subst_with_literals(x::Any, subst::Dict{Symbol,Any})
    if x isa Symbol
        return haskey(subst, x) ? Meta.quot(subst[x]) : x
    elseif x isa Expr
        return Expr(x.head, (_subst_with_literals(a, subst) for a in x.args)...)
    else
        return x
    end
end

function eval_semantic_side(side::Any, subst::Dict{Symbol,Any})
    if !(side isa Expr) && !(side isa Symbol)
        return side
    end

    ex2 = _subst_with_literals(side, subst)

    try
        return eval(ex2)
    catch
        return nothing
    end
end