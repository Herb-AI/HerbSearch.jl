include("../utils/muc_utils.jl")

mutable struct MUC <: AbstractConflictTechnique
    solver::InteractiveSolver
    input::Union{MUCInput, Nothing}
    data::Union{UnsatCoreData, Nothing}
end

function MUC(solver=CVC5())
    interactive_solver = open(solver)
    
    send_command(interactive_solver, "(set-option :produce-unsat-cores true)", dont_wait=true)

    return MUC(interactive_solver, nothing, nothing)
end
    
function check_conflict(technique::MUC)
    grammar = technique.input.grammar
    root = technique.input.root
    interactive_solver = technique.solver

    smt_specmodel = infer_spec(root, grammar, technique.input.counter_example)

    core = smt_solve(smt_specmodel, interactive_solver)
    
    if core === nothing
        return nothing
    end

    muc_constraint_node_map = core_to_constraints(parse_core_ids(core), smt_specmodel.cons_id_map)

    muc_semantic_node_map = constraints_to_semantics(muc_constraint_node_map, root, grammar, smt_specmodel.bank)

    return UnsatCoreData(muc_semantic_node_map)
end

function analyze_conflict(technique::MUC)
    root = technique.input.root
    grammar = technique.input.grammar
    arity = max_arity(grammar)
    muc_map = technique.data.core_constraints_map

    # Determine if root is part of the conflict and create root of new tree
    if haskey(muc_map, 0)
        rules = extract_emc_class(muc_map[0], grammar, return_type(grammar, get_rule(root)), grammar.childtypes[get_rule(root)])
        if length(rules) > 1
            emc_root = DomainRuleNode(grammar, rules, [freeze_state(child) for child in get_children(root)])
        else 
            emc_root = RuleNode(get_rule(root), [freeze_state(child) for child in get_children(root)])
        end
    else
        emc_root = RuleNode(get_rule(root), [freeze_state(child) for child in get_children(root)])
    end

    # Parallel BFS queues: one for original, one for new tree
    original_q = Queue{AbstractRuleNode}()
    rebuilt_q = Queue{AbstractRuleNode}()
    enqueue!(original_q, root)
    enqueue!(rebuilt_q, emc_root)

    while !isempty(original_q)
        curr_orig = dequeue!(original_q)
        curr_new = dequeue!(rebuilt_q)

        for (i, child_orig) in enumerate(get_children(curr_orig))
            child_id = get_index(get_path(root, child_orig), arity)
            child_rule = get_rule(child_orig)

            # Create new node depending on whether it's in the conflict
            if haskey(muc_map, child_id)
                rules = extract_emc_class(muc_map[child_id], grammar, return_type(grammar, child_rule), grammar.childtypes[child_rule])
                if length(rules) > 1
                    child_new = DomainRuleNode(grammar, rules, [freeze_state(child) for child in get_children(child_orig)])
                else
                    child_new = RuleNode(child_rule, [freeze_state(child) for child in get_children(child_orig)])
                end
            elseif isterminal(grammar, child_rule) && curr_new isa DomainRuleNode && !occursin("arg", string(grammar.rules[child_rule]))
                child_new = DomainRuleNode(grammar, get_typed_terminals_list(grammar, child_rule))
            else
                child_new = RuleNode(child_rule, [freeze_state(child) for child in get_children(child_orig)])
            end

            curr_new.children[i] = child_new
            enqueue!(original_q, child_orig)
            enqueue!(rebuilt_q, child_new)
        end
    end

    return MUCConstraint(Forbidden(emc_root), "MUC")
end

function close(technique::MUC)
    close(technique.solver)
end
