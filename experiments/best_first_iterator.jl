using DataStructures
include("../src/HerbSearch.jl")
using HerbCore, HerbGrammar, .HerbSearch, HerbSpecification, HerbBenchmarks

struct BestFirstIterator 
    grammar :: ContextSensitiveGrammar
    start_symbol :: Symbol
    cost_function :: Function
end

function Base.iterate(iter::BestFirstIterator)
    grammar = iter.grammar
    queue = PriorityQueue()

    # enqueue initial trees for start_type
    for rid in reverse(grammar.bytype[iter.start_symbol])
        # children = [Hole(BitVector[]) for _ in grammar.childtypes[rid]]  # placeholder children
        children = [Hole(BitVector([])) for _ in grammar.childtypes[rid]]  # placeholder children

        node = RuleNode(rid, children)

        depth = 0
        cost = iter.cost_function(node)
        enqueue!(queue, (node, cost), (cost, depth))
    end

    return Base.iterate(iter, queue)
end

function Base.iterate(iter::BestFirstIterator, queue::DataStructures.PriorityQueue)
    if isempty(queue)
        return nothing
    end

    current, cost = dequeue!(queue)
    yield = current

    if cost == 0
        return ((yield, cost), PriorityQueue())
    end

    # locate first unfinished node (with rule_id == -1)
    path = find_leftmost_unfinished(current)
    if path !== nothing
        parent = get_node_by_path(current, path[1:end-1])
        idx = path[end]
        type_needed = iter.grammar.childtypes[parent.ind][idx]

        for rid in reverse(iter.grammar.bytype[type_needed])
            # sub_children = [Hole(BitVector[]) for _ in iter.grammar.childtypes[rid]]
            sub_children = [Hole(BitVector([])) for _ in iter.grammar.childtypes[rid]]

            replacement = RuleNode(rid, sub_children)

            new_tree = deepcopy(current)
            insert_at_path!(new_tree, path, replacement)

            depth = length(path)
            new_cost = iter.cost_function(new_tree)

            enqueue!(queue, (new_tree, new_cost), (new_cost, depth))
        end
    end

    return ((yield, cost), queue)
end

# Return path to first unfinished node as a vector of indices
function find_leftmost_unfinished(node::AbstractRuleNode, path=Int[])
    if node isa Hole
        return path
    end
    for (i, child) in enumerate(node.children)
        subpath = find_leftmost_unfinished(child, [path...; i])
        if subpath !== nothing
            return subpath
        end
    end
    return nothing
end

# Get node at a path like [2, 1] (i.e. second child’s first child)
function get_node_by_path(node::AbstractRuleNode, path::Vector{Int})
    for i in path
        node = node.children[i]
    end
    return node
end

# Insert a node at a given path (in-place)
function insert_at_path!(node::AbstractRuleNode, path::Vector{Int}, newnode::AbstractRuleNode)
    for i in 1:length(path)-1
        node = node.children[path[i]]
    end
    node.children[path[end]] = newnode
end


# grammar = @csgrammar begin
#     Exp = Int
#     Int = 4
#     Int = Int * Int
#     Int = Int + Int
# end

# function interpret(node::RuleNode)::Any
#     if node.ind == -1
#         # Unfinished node: treat as identity (return nothing or child if exists)
#         if isempty(node.children)
#             return 4
#         else
#             # Just interpret first completed child if any
#             for child in node.children
#                 result = interpret(child)
#                 if result !== 0
#                     return result
#                 end
#             end
#             return 4
#         end
#     end

#     rule = grammar.rules[node.ind]
#     child_values = [interpret(c) for c in node.children]

#     return interpret_rule(rule, child_values)
# end

# function interpret_rule(rule, args::Vector)
#     if rule == 4
#         return 4
#     elseif rule isa Expr
#         if rule.head == :call
#             op = rule.args[1]
#             if op == :+
#                 return foldl(+, args)
#             elseif op == :*
#                 return foldl(*, args)
#             else
#                 error("Unsupported operator: $op")
#             end
#         else
#             error("Unsupported expression: $rule")
#         end
#     elseif rule isa Symbol
#         return args[1]  # type alias rule (e.g., Exp = Int)
#     else
#         error("Unknown rule type: $rule")
#     end
# end


# function cost_function(program)
#     res = interpret(program)
#     expected = 64

#     return log2(64) - log2(res)
# end

# iterator = BestFirstIterator(grammar, :Exp, cost_function)

# global count = 0
# for (program, cost) in iterator
#     println("Program $program")
#     println("Cost $cost")
#     res = interpret(program)
#     println("Result $res")
# end