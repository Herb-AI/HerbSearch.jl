"""
Enumerates a context-free grammar up to a given depth in a breadth-first order.
This means that smaller programs are returned before larger programs.
"""
mutable struct ContextSensitivePriorityEnumerator <: ExpressionIterator 
    grammar::ContextSensitiveGrammar
    max_depth::Int
    max_size::Int
    # Assigns a priority to a (partial or complete) tree.
    priority_function::Function
    # Expands a partial tree.
    expand_function::Function
    sym::Symbol
end 

@enum ExpandFailureReason limit_reached=1 already_complete=2

TreeConstraints = Tuple{AbstractRuleNode, Vector{LocalConstraint}}

struct PQItem 
    tree::AbstractRuleNode
    size::Int
    constraints::Vector{LocalConstraint}
end
PQItem(tree::AbstractRuleNode, size::Int) = PQItem(tree, size, [])

function Base.iterate(iter::ContextSensitivePriorityEnumerator)
    # Priority queue with number of nodes in the program
    pq :: PriorityQueue{PQItem, Union{Real, Tuple{Vararg{Real}}}} = PriorityQueue()

    grammar, max_depth, max_size, sym = iter.grammar, iter.max_depth, iter.max_size, iter.sym
    priority_function, expand_function = iter.priority_function, iter.expand_function

    init_node = Hole(get_domain(grammar, sym))
    new_domain, new_constraints::Vector{LocalConstraint} = propagate_constraints(
        grammar, 
        GrammarContext(init_node, [], []), 
        findall(init_node.domain)
    )
    init_node.domain = get_domain(grammar, new_domain)

    enqueue!(pq, PQItem(init_node, 0, new_constraints), priority_function(grammar, init_node, 0))
    
    return _find_next_complete_tree(grammar, max_depth, max_size, priority_function, expand_function, pq)
end


function Base.iterate(iter::ContextSensitivePriorityEnumerator, pq::DataStructures.PriorityQueue)
    grammar, max_depth, max_size = iter.grammar, iter.max_depth, iter.max_size
    priority_function, expand_function = iter.priority_function, iter.expand_function
    return _find_next_complete_tree(grammar, max_depth, max_size, priority_function, expand_function, pq)
end


function propagate_all_holes(
    root::AbstractRuleNode,
    grammar::ContextSensitiveGrammar,
    local_constraints::Vector{LocalConstraint}
)::Vector{LocalConstraint}
    function dfs(node::RuleNode, path::Vector{Int})::Vector{HeuristicResult}
        holes::Vector{HeuristicResult} = []

        for (i, child) in enumerate(node.children)
            new_path = push!(copy(path), i)
            append!(holes, dfs(child, new_path))
        end

        return holes
    end

    function dfs(hole::Hole, path::Vector{Int})::Vector{HeuristicResult}
        return [(hole, path)]
    end

    new_local_constraints = local_constraints
    for (hole, path) ∈ dfs(root, Vector{Int}())
        new_domain, new_local_constraints = propagate_constraints(
            grammar, 
            GrammarContext(root, path, new_local_constraints), 
            findall(hole.domain)
        )
        hole.domain = get_domain(grammar, new_domain)
    end

    return new_local_constraints
end

"""
Reduces the set of possible children of a node using the grammar's constraints
"""
function propagate_constraints(
        grammar::ContextSensitiveGrammar, 
        context::GrammarContext, 
        child_rules::Vector{Int}
    )::Tuple{Vector{Int}, Vector{LocalConstraint}}
    domain = child_rules
    new_local_constraints::Vector{LocalConstraint} = []

    # Local constraints that are specific to this rulenode
    for constraint ∈ context.constraints
        domain, local_constraints = propagate(constraint, grammar, context, domain)
        domain == [] && return domain, []
        # TODO: Should we check for duplicates?
        append!(new_local_constraints, local_constraints)
    end

    # General constraints for the entire grammar
    for constraint ∈ grammar.constraints
        domain, local_constraints = propagate(constraint, grammar, context, domain)
        domain == [] && return domain, []
        append!(new_local_constraints, local_constraints)
    end

    return domain, new_local_constraints
end


"""
Takes a priority queue and returns the smallest AST from the grammar it can obtain from the
queue or by (repeatedly) expanding trees that are in the queue.
Returns nothing if there are no trees left within the depth limit.
"""
function _find_next_complete_tree(
    grammar::ContextSensitiveGrammar, 
    max_depth::Int, 
    max_size::Int,
    priority_function::Function, 
    expand_function::Function, 
    pq::PriorityQueue
)::Union{Tuple{RuleNode, PriorityQueue}, Nothing}
    while length(pq) ≠ 0
        (pqitem, priority_value) = dequeue_pair!(pq)
        if pqitem.size == max_size
            # Check if tree contains holes
            if contains_hole(pqitem.tree)
                # There is no need to expand this tree, since the size limit is reached
                continue
            end
            return (pqitem.tree, pq)
        elseif pqitem.size ≥ max_size
            continue
        end
        expand_result = expand_function(pqitem.tree, grammar, max_depth, GrammarContext(pqitem.tree, [], pqitem.constraints))
        if expand_result ≡ already_complete
            # Current tree is complete, it can be returned
            return (pqitem.tree, pq)
        elseif expand_result ≡ limit_reached
            # The maximum depth is reached
            continue
        elseif expand_result isa Vector{TreeConstraints}
            # Either the current tree can't be expanded due to depth 
            # limit (no expanded trees), or the expansion was successful. 
            # We add the potential expanded trees to the pq and move on to 
            # the next tree in the queue.
            for (expanded_tree, local_constraints) ∈ expand_result
                # expanded_tree is a new program tree with a new expanded child compared to pqitem.tree
                # new_holes are all the holes in expanded_tree
                new_pqitem = PQItem(expanded_tree, pqitem.size + 1, local_constraints)
                enqueue!(pq, new_pqitem, priority_function(grammar, expanded_tree, priority_value))
            end
        else
            error("Got an invalid response of type $(typeof(expand_result)) from expand function")
        end
    end
    return nothing
end

"""
Recursive expand function used in multiple enumeration techniques.
Expands one hole/undefined leaf of the given RuleNode tree.
The first hole found using the given hole heuristic
If the expansion was successful, returns a list of new trees and a
list of lists of hole locations, corresponding to the holes of each
new expanded tree. 
Returns nothing if tree is already complete (contains no holes).
Returns empty list if the tree is partial (contains holes), 
    but they couldn't be expanded because of the depth limit.
"""
function _expand(
        root::RuleNode, 
        grammar::ContextSensitiveGrammar, 
        max_depth::Int, 
        context::GrammarContext, 
        hole_heuristic::Function,
        value_heuristic::Function,
    )::Union{ExpandFailureReason, Vector{TreeConstraints}}
    hole_res = hole_heuristic(root, max_depth)
    if hole_res isa ExpandFailureReason
        return hole_res
    elseif hole_res isa HeuristicResult
        # Hole was found
        hole, node_location = hole_res
        hole_context = GrammarContext(context.originalExpr, node_location, context.constraints)
        expanded_child_trees = _expand(hole, grammar, max_depth, hole_context, hole_heuristic, value_heuristic)

        nodes::Vector{TreeConstraints} = []
        for (expanded_tree, local_constraints) ∈ expanded_child_trees
            copied_root = deepcopy(root)

            parent_node = get_node_at_location(copied_root, node_location[1:end-1])
            parent_node.children[node_location[end]] = expanded_tree

            new_local_constraints = propagate_all_holes(copied_root, grammar, local_constraints)

            push!(nodes, (copied_root, new_local_constraints))
        end
        
        return nodes
    else
        error("Got an invalid response of type $(typeof(expand_result)) from `hole_heuristic` function")
    end
end

function _expand(
    node::Hole, 
    grammar::ContextSensitiveGrammar, 
    max_depth::Int, 
    context::GrammarContext, 
    hole_heuristic::Function,
    value_heuristic::Function,
)::Union{ExpandFailureReason, Vector{TreeConstraints}}
    nodes::Vector{TreeConstraints} = []
    
    for rule_index ∈ value_heuristic(findall(node.domain))
        push!(nodes, (RuleNode(rule_index, grammar), context.constraints))
    end

    return nodes
end