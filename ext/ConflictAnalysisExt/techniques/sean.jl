include("../utils/sean_utils.jl")

mutable struct SeAn <: AbstractConflictTechnique
    input::Union{SeAnInput, Nothing}
    data::Union{SeAnData, Nothing}
    conflict_history::Dict{Expr, Vector{AbstractRuleNode}}
end

function SeAn()
    return SeAn(nothing, nothing, Dict{Expr, Vector{AbstractRuleNode}}())
end

function check_conflict(technique::SeAn)
    node = technique.input.root
    grammar = technique.input.grammar
    symboltable = technique.input.symboltable

    while grammar.rules[get_rule(node)] isa Symbol
        if length(get_children(node)) != 1
            return nothing
        end
        node = get_children(node)[1]
    end

    if isempty(grammar.specification[get_rule(node)])
        return nothing
    end

    # Create a symbol dict holding evaluation results of output and inputs of root node.
    result_dict = Dict{Symbol, Any}()
    result_dict[:y] = technique.input.counter_example.out
    for (i, child) in enumerate(get_children(node))
        expr = rulenode2expr(child, grammar)
        try
            result_dict[Symbol("x$i")] = execute_on_input(symboltable, expr, technique.input.counter_example.in)
        catch e
            # println("Failed to evaluate child expression: $expr")
            # println("Error: $e")
            return nothing
        end
    end

    # Check for every semantic in the grammar specification of the root node
    # if it is violated by the given evaluations.
    semantics = Vector{Expr}()
    for semantic in technique.input.grammar.specification[get_rule(node)]
        try
            # Evaluate the semantic expression with the result_dict
            # If it evaluates to false, it is a violation.
            if !evaluate_expr_naive(semantic, result_dict)
                push!(semantics, semantic)
            end
        catch e
            # Do nothing if evaluation fails, as it might be a syntax error or unsupported operation.
        end
    end
    
    # If no semantics are violated, skip analyze conflict
    if isempty(semantics)
        return nothing
    end

    return SeAnData(semantics)
end

function analyze_conflict(technique::SeAn)
    node = freeze_state(technique.input.root)
    grammar = technique.input.grammar

    while grammar.rules[get_rule(node)] isa Symbol && isempty(grammar.specification[get_rule(node)])
        if length(get_children(node)) != 1
            return nothing
        end
        node = get_children(node)[1]
    end
    
    constraints = Vector{SeAnConstraint}()
    for semantic in technique.data.semantics
        # Extract the EMC class from the semantic expression
        sec_class = extract_sec(semantic, grammar, return_type(grammar, node), grammar.childtypes[get_rule(node)])

        # If no class is found, skip this semantic
        if length(sec_class) < 2
            continue
        end

        # Create a new tree structure for the forbidden constraint
        tree = DomainRuleNode(grammar, sec_class, [freeze_state(child) for child in get_children(node)])

        for (i, child) in enumerate(get_children(tree))
            child_rule = get_rule(child)

            if isterminal(grammar, child_rule) && !occursin("arg", string(grammar.rules[child_rule]))
                child_new = DomainRuleNode(grammar, get_typed_terminals_list(grammar, child_rule))
            else
                child_new = child
            end

            # Attach and continue traversal
            tree.children[i] = child_new
        end
        
        push!(constraints, SeAnConstraint(Forbidden(tree), "$semantic"))
    end

    return constraints
end